"""Lambda handler: fetch papers from PubMed via NCBI E-utilities."""

import json
import logging
import os
import time
import urllib.request
import xml.etree.ElementTree as ET

from shared.s3_client import upload_file

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

EUTILS_BASE = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
}


def _ncbi_get(url: str) -> bytes:
    """Fetch a URL from NCBI, respecting rate limits (max 3 req/sec)."""
    time.sleep(0.34)  # ~3 requests per second
    req = urllib.request.Request(url)
    req.add_header("User-Agent", "DermaIntel/1.0")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


def _esearch(journals: list[str], date_from: str, date_to: str, retmax: int = 100) -> list[str]:
    """Search PubMed for dermatology paper IDs matching filters."""
    journal_query = " OR ".join(f'"{j}"[Journal]' for j in journals)
    query = f"({journal_query}) AND (\"{date_from}\"[PDAT] : \"{date_to}\"[PDAT])"
    params = urllib.request.quote(query)
    url = f"{EUTILS_BASE}/esearch.fcgi?db=pubmed&term={params}&retmax={retmax}&retmode=json"

    data = _ncbi_get(url)
    result = json.loads(data)
    id_list = result.get("esearchresult", {}).get("idlist", [])
    logger.info("esearch returned %d paper IDs", len(id_list))
    return id_list


def _efetch(paper_ids: list[str]) -> list[dict]:
    """Fetch paper details from PubMed for a list of IDs."""
    papers = []
    # Process in batches of 20 to respect NCBI limits
    for i in range(0, len(paper_ids), 20):
        batch = paper_ids[i : i + 20]
        ids_str = ",".join(batch)
        url = f"{EUTILS_BASE}/efetch.fcgi?db=pubmed&id={ids_str}&rettype=xml&retmode=xml"

        xml_data = _ncbi_get(url)
        root = ET.fromstring(xml_data)

        for article in root.findall(".//PubmedArticle"):
            try:
                pmid_el = article.find(".//PMID")
                pmid = pmid_el.text if pmid_el is not None else ""

                title_el = article.find(".//ArticleTitle")
                title = title_el.text if title_el is not None else ""

                abstract_el = article.find(".//AbstractText")
                abstract = abstract_el.text if abstract_el is not None else ""

                journal_el = article.find(".//Journal/Title")
                journal = journal_el.text if journal_el is not None else ""

                year_el = article.find(".//PubDate/Year")
                year = year_el.text if year_el is not None else ""

                authors = []
                for author in article.findall(".//Author"):
                    last = author.find("LastName")
                    first = author.find("ForeName")
                    if last is not None and first is not None:
                        authors.append(f"{last.text} {first.text}")

                papers.append({
                    "paper_id": f"PMID:{pmid}",
                    "title": title,
                    "abstract": abstract,
                    "journal": journal,
                    "pub_date": year,
                    "authors": authors,
                })
            except Exception:
                logger.warning("Failed to parse article", exc_info=True)

    return papers


def _try_download_pdf(paper_id: str, bucket: str) -> str:
    """Attempt to download a PDF from PubMed Central. Returns S3 key or empty string."""
    pmid = paper_id.replace("PMID:", "")
    pmc_url = (
        f"{EUTILS_BASE}/elink.fcgi?dbfrom=pubmed&db=pmc&id={pmid}&retmode=json"
    )
    try:
        data = _ncbi_get(pmc_url)
        result = json.loads(data)
        link_sets = result.get("linksets", [])
        if not link_sets:
            return ""
        links = link_sets[0].get("linksetdbs", [])
        pmc_ids = []
        for ls in links:
            if ls.get("dbto") == "pmc":
                pmc_ids = [str(lid["id"]) for lid in ls.get("links", [])]
                break
        if not pmc_ids:
            return ""

        pmc_id = pmc_ids[0]
        pdf_url = f"https://www.ncbi.nlm.nih.gov/pmc/articles/PMC{pmc_id}/pdf/"
        pdf_data = _ncbi_get(pdf_url)

        s3_key = f"papers/pdfs/{paper_id.replace(':', '_')}.pdf"
        upload_file(bucket, s3_key, pdf_data, "application/pdf")
        return s3_key
    except Exception:
        logger.info("No PDF available for %s", paper_id)
        return ""


def handler(event, context):
    """Lambda handler for PubMed paper fetching.

    Event fields:
        journals: list[str] - target journal names
        date_from: str - start date (YYYY/MM/DD)
        date_to: str - end date (YYYY/MM/DD)
        max_results: int - maximum papers to fetch (default 100)
    """
    try:
        journals = event.get("journals", [
            "Journal of the American Academy of Dermatology",
            "British Journal of Dermatology",
            "JAMA Dermatology",
            "Journal of Investigative Dermatology",
        ])
        date_from = event.get("date_from", "2024/01/01")
        date_to = event.get("date_to", "2024/12/31")
        max_results = event.get("max_results", 100)
        bucket = os.environ.get("DATA_BUCKET", "dermaintel-data")

        # Step 1: Search for paper IDs
        paper_ids = _esearch(journals, date_from, date_to, retmax=max_results)
        if not paper_ids:
            return {
                "statusCode": 200,
                "headers": CORS_HEADERS,
                "body": json.dumps({"papers": [], "count": 0}),
            }

        # Step 2: Fetch paper details
        papers = _efetch(paper_ids)

        # Step 3: Try to download PDFs to S3
        for paper in papers:
            pdf_key = _try_download_pdf(paper["paper_id"], bucket)
            paper["pdf_s3_key"] = pdf_key

            # Also store abstract XML in S3
            abstract_key = f"papers/abstracts/{paper['paper_id'].replace(':', '_')}.json"
            upload_file(bucket, abstract_key, json.dumps(paper), "application/json")

        # Return paper IDs for Step Functions Map state
        result = {
            "papers": [{"paper_id": p["paper_id"], "pdf_s3_key": p["pdf_s3_key"]} for p in papers],
            "count": len(papers),
        }

        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps(result),
        }

    except Exception as e:
        logger.error("PubMed fetch failed", exc_info=True)
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": str(e)}),
        }

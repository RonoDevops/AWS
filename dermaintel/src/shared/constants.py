"""Constants for the DermaIntel project."""

BEDROCK_MODELS: dict[str, str] = {
    "haiku": "anthropic.claude-3-5-haiku-20241022-v1:0",
    "sonnet": "anthropic.claude-sonnet-4-20250514-v1:0",
}

CONDITION_ALIASES: dict[str, str] = {
    "eczema": "atopic_dermatitis",
    "atopic dermatitis": "atopic_dermatitis",
    "ad": "atopic_dermatitis",
    "psoriasis": "psoriasis",
    "plaque psoriasis": "psoriasis",
    "acne": "acne_vulgaris",
    "acne vulgaris": "acne_vulgaris",
    "rosacea": "rosacea",
    "melanoma": "melanoma",
    "malignant melanoma": "melanoma",
    "bcc": "basal_cell_carcinoma",
    "basal cell carcinoma": "basal_cell_carcinoma",
    "scc": "squamous_cell_carcinoma",
    "squamous cell carcinoma": "squamous_cell_carcinoma",
    "vitiligo": "vitiligo",
    "alopecia areata": "alopecia_areata",
    "hidradenitis suppurativa": "hidradenitis_suppurativa",
    "hs": "hidradenitis_suppurativa",
    "urticaria": "urticaria",
    "chronic urticaria": "urticaria",
    "pemphigus": "pemphigus",
    "bullous pemphigoid": "bullous_pemphigoid",
    "dermatomyositis": "dermatomyositis",
    "scleroderma": "scleroderma",
    "lupus": "cutaneous_lupus",
    "cutaneous lupus": "cutaneous_lupus",
}

JOURNAL_CODES: dict[str, str] = {
    "JAAD": "Journal of the American Academy of Dermatology",
    "BJD": "British Journal of Dermatology",
    "JID": "Journal of Investigative Dermatology",
    "AD": "Acta Dermato-Venereologica",
    "JAMA Derm": "JAMA Dermatology",
    "Dermatol Ther": "Dermatologic Therapy",
    "Exp Dermatol": "Experimental Dermatology",
    "Br J Dermatol": "British Journal of Dermatology",
    "J Eur Acad Dermatol": "Journal of the European Academy of Dermatology and Venereology",
    "Arch Dermatol Res": "Archives of Dermatological Research",
}

EVIDENCE_GRADES: dict[str, str] = {
    "systematic_review": "A",
    "meta_analysis": "A",
    "rct": "A",
    "randomized_controlled_trial": "A",
    "cohort_study": "B",
    "prospective_cohort": "B",
    "case_control": "B",
    "cross_sectional": "C",
    "case_series": "C",
    "case_report": "C",
    "expert_opinion": "C",
    "narrative_review": "C",
    "in_vitro": "C",
    "animal_study": "C",
}

MEDICAL_DISCLAIMER: str = (
    "DISCLAIMER: This information is generated from published dermatology research "
    "and is intended for educational and informational purposes only. It does NOT "
    "constitute medical advice, diagnosis, or treatment recommendations. Always "
    "consult a qualified healthcare professional for clinical decisions. The evidence "
    "grades reflect study design quality and do not guarantee applicability to "
    "individual patients."
)

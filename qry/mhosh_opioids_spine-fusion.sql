WITH PT_LIST AS (
	SELECT DISTINCT
		ENCNTR_ALIAS.ALIAS,
		ENCOUNTER.ENCNTR_ID,
		SURGICAL_CASE.SURG_STOP_DT_TM
	FROM
		ENCNTR_ALIAS,
		ENCOUNTER,
		SURGICAL_CASE,
		SURG_CASE_PROCEDURE
	WHERE
		ENCNTR_ALIAS.ALIAS IN @prompt('Enter value(s) for Alias','A',,Multi,Free,Persistent,,User:0)
		AND ENCNTR_ALIAS.ENCNTR_ALIAS_TYPE_CD = 619 -- FIN NBR
		AND ENCNTR_ALIAS.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
		AND ENCNTR_ALIAS.ENCNTR_ID = SURGICAL_CASE.ENCNTR_ID
		AND SURGICAL_CASE.SURG_START_DT_TM >= ENCOUNTER.ARRIVE_DT_TM
		AND SURGICAL_CASE.SURG_AREA_CD > 0
		AND SURGICAL_CASE.SURG_CASE_ID = SURG_CASE_PROCEDURE.SURG_CASE_ID
		AND SURG_CASE_PROCEDURE.ACTIVE_IND = 1
)

SELECT
	PT_LIST.ALIAS AS FIN,
	pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, (pi_time_zone(1, @Variable('BOUSER')))) AS DOSE_DATETIME,
	pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS MEDICATION,
	ORDERS.ORDER_MNEMONIC AS MED_PRODUCT,
	CE_MED_RESULT.ADMIN_DOSAGE AS DOSE,
	pi_get_cv_display(CE_MED_RESULT.DOSAGE_UNIT_CD) AS DOSE_UNIT,
	CE_MED_RESULT.INFUSION_RATE AS RATE,
	pi_get_cv_display(CE_MED_RESULT.INFUSION_UNIT_CD) AS RATE_UNIT,
	pi_get_cv_display(CE_MED_RESULT.IV_EVENT_CD) AS IV_EVENT,
	pi_get_cv_display(CE_MED_RESULT.ADMIN_ROUTE_CD) AS ROUTE
FROM
	CE_MED_RESULT,
	CLINICAL_EVENT,
	ORDERS,
	PT_LIST
WHERE
	PT_LIST.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
	AND CLINICAL_EVENT.EVENT_CLASS_CD = 158 -- MED
	AND CLINICAL_EVENT.EVENT_CD IN (
		37556014, --acetaminophen-codeine
		37556016, --acetaminophen-hydrocodone
		37556017, --acetaminophen-oxycodone
		37556018, --acetaminophen-pentazocine
		37556023, --acetaminophen-tramadol
		37556061, --alfentanil
		37556161, --APAP/butalbital/caffeine/codeine
		37556163, --APAP/caffeine/dihydrocodeine
		37556178, --ASA/butalbital/caffeine/codeine
		37556179, --ASA/caffeine/dihydrocodeine
		37556181, --ASA/caffeine/propoxyphene
		37556193, --aspirin-codeine
		37556197, --aspirin-oxycodone
		37556198, --aspirin-pentazocine
		37556263, --belladonna-opium
		37556352, --buprenorphine
		37556359, --butorphanol
		37556595, --codeine
		37556814, --droperidol-fentanyl
		37556956, --FENTanyl
		37557191, --HYDROcodone-ibuprofen
		37557204, --HYDROmorphone
		37557424, --levorphanol
		37557517, --meperidine
		37557519, --meperidine-promethazine
		37557538, --methadone
		37557620, --morphine Sulfate
		37557645, --nalbuphine
		37557648, --naloxone-pentazocine
		37557727, --opium
		37557746, --OXYcodone
		37557790, --pentazocine
		37557973, --remifentanil
		37558121, --sufentanil
		37558239, --tramadol
		99783187, --morphine liposomal
		103856893, --fentanyl-ropivacaine
		117038566, --bupivacaine-fentanyl
		117038567, --bupivacaine-hydromorphone
		117038568, --buprenorphine-naloxone
		117038681, --dihydrocodeine
		117038771, --HYDROcodone
		117038789, --ibuprofen-oxycodone
		117038901, --oxymorphone
		405732895, --tapentadol
		423546842, --morphine-naltrexone
		538590483, --ropivacaine-sufentanil
		1651062812, --HYDROmorphone-ropivacaine
		2180033613, --bupivacaine-SUFentanil
		3135779565 --acetaminophen-benzhydrocodone
	)
	AND CLINICAL_EVENT.EVENT_END_DT_TM > PT_LIST.SURG_STOP_DT_TM
	AND CLINICAL_EVENT.ORDER_ID = ORDERS.ORDER_ID
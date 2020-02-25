WITH PT_LIST AS (
	SELECT DISTINCT
		ENCNTR_ALIAS.ALIAS,
		ENCOUNTER.ENCNTR_ID,
		SURGICAL_CASE.SURG_STOP_DT_TM,
		ENCOUNTER.DISCH_DT_TM
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
), DOSES AS (
	SELECT DISTINCT
		PT_LIST.ENCNTR_ID,
		CLINICAL_EVENT.EVENT_ID,
		LOWER(pi_get_cv_display(CLINICAL_EVENT.EVENT_CD)) AS EVENT,
		CLINICAL_EVENT.EVENT_CD,
		LOWER(ORDERS.ORDER_MNEMONIC) AS ORDER_MNEMONIC,
		CE_MED_RESULT.ADMIN_DOSAGE,
		pi_get_cv_display(CE_MED_RESULT.DOSAGE_UNIT_CD) AS DOSAGE_UNIT,
		CE_MED_RESULT.DOSAGE_UNIT_CD,
		CE_MED_RESULT.INFUSION_RATE,
		pi_get_cv_display(CE_MED_RESULT.INFUSION_UNIT_CD) AS INFUSION_UNIT,
		CE_MED_RESULT.INFUSION_UNIT_CD,
		pi_get_cv_display(CE_MED_RESULT.IV_EVENT_CD) AS IV_EVENT,
		CE_MED_RESULT.IV_EVENT_CD,
		pi_get_cv_display(CE_MED_RESULT.ADMIN_ROUTE_CD) AS ROUTE,		
		CE_MED_RESULT.ADMIN_ROUTE_CD
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
		AND CLINICAL_EVENT.EVENT_ID = CE_MED_RESULT.EVENT_ID
		AND CLINICAL_EVENT.ORDER_ID = ORDERS.ORDER_ID
), DOSE_CALC AS (
	SELECT
		DOSES.*,
		CASE 
			WHEN REGEXP_INSTR(ORDER_MNEMONIC, 'pca') > 0 THEN 0
			WHEN DOSAGE_UNIT = 'tab' THEN 
				CASE 
					WHEN REGEXP_INSTR(ORDER_MNEMONIC, '50( )?mg') > 0 THEN ADMIN_DOSAGE * 50
					WHEN REGEXP_INSTR(ORDER_MNEMONIC, '30( )?mg') > 0 THEN ADMIN_DOSAGE * 30
					WHEN REGEXP_INSTR(ORDER_MNEMONIC, '15( )?mg') > 0 THEN ADMIN_DOSAGE * 15
					WHEN REGEXP_INSTR(ORDER_MNEMONIC, '10( )?mg') > 0 THEN ADMIN_DOSAGE * 10
					WHEN REGEXP_INSTR(ORDER_MNEMONIC, '7.5( )?mg') > 0 THEN ADMIN_DOSAGE * 7.5
					WHEN REGEXP_INSTR(ORDER_MNEMONIC, '5( )?mg') > 0 THEN ADMIN_DOSAGE * 5
					WHEN REGEXP_INSTR(ORDER_MNEMONIC, '4( )?mg') > 0 THEN ADMIN_DOSAGE * 4
					WHEN REGEXP_INSTR(ORDER_MNEMONIC, '2( )?mg') > 0 THEN ADMIN_DOSAGE * 2
					WHEN REGEXP_INSTR(ORDER_MNEMONIC, '1( )?mg') > 0 THEN ADMIN_DOSAGE * 1
				END
			WHEN DOSAGE_UNIT = 'microgram' THEN ADMIN_DOSAGE / 1000
			ELSE ADMIN_DOSAGE
		END AS DOSE_MG,
		CASE
			WHEN REGEXP_INSTR(EVENT, 'codeine') > 0 THEN 0.15
			WHEN REGEXP_INSTR(EVENT, 'fentanyl') > 0 THEN
				CASE 
					WHEN REGEXP_INSTR(ROUTE, 'IM|IV|INJ') > 0 THEN 300
					WHEN REGEXP_INSTR(ROUTE, 'TOP') > 0 THEN 7200
					ELSE 100
				END
			WHEN REGEXP_INSTR(EVENT, 'hydrocodone') > 0 THEN 1
			WHEN REGEXP_INSTR(EVENT, 'hydromorphone') > 0 THEN 
				CASE 
					WHEN REGEXP_INSTR(ROUTE, 'IM|IV|INJ') > 0 THEN 20
					ELSE 4
				END
			WHEN REGEXP_INSTR(EVENT, 'meperidine') > 0 THEN 0.3
			WHEN REGEXP_INSTR(EVENT, 'morphine') > 0 THEN
				CASE 
					WHEN REGEXP_INSTR(ROUTE, 'IM|IV|INJ') > 0 THEN 3
					ELSE 1
				END		
			WHEN REGEXP_INSTR(EVENT, 'oxycodone') > 0 THEN 1.5
			WHEN REGEXP_INSTR(EVENT, 'tramadol') > 0 THEN 0.1
		END AS ORAL_MME_CONVERSION
	FROM
		DOSES
), MME_CALC AS (
	SELECT
		DOSE_CALC.*,
		DOSE_MG * ORAL_MME_CONVERSION AS ORAL_MME
	FROM
		DOSE_CALC
), MME_TOTALS AS (
	SELECT 
		MME_CALC.ENCNTR_ID,
		SUM(MME_CALC.ORAL_MME) AS INTERMIT_MME_TOTAL
	FROM
		MME_CALC
	GROUP BY
		MME_CALC.ENCNTR_ID
), PCA_DATA AS (
	SELECT DISTINCT
		PT_LIST.ENCNTR_ID,
		--CLINICAL_EVENT.EVENT_ID,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		--CLINICAL_EVENT.EVENT_CD,
		pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS EVENT,
		CLINICAL_EVENT.RESULT_VAL
	FROM
		CLINICAL_EVENT,
		PT_LIST
	WHERE
		PT_LIST.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD IN (
			159, -- NUM
			162 -- TXT
		)
		AND CLINICAL_EVENT.EVENT_CD IN (
			1353917535, -- PCA Clinician Bolus
			1353917564, -- PCA Clinician Bolus Unit
			700103069, -- PCA Concentration
			700103420, -- PCA Continuous Rate Dose
			700103515, -- PCA Demand Dose
			700103573, -- PCA Demand Dose Unit
			1353917859, -- PCA Doses Delivered
			900876112, -- PCA Drug
			802776519, -- PCA Loading Dose
			700103330, -- PCA Lockout Interval (minutes)
			700104137, -- PCA Number of Attempts
			700104271, -- PCA Number of Injections
			900876333, -- PCA Number of Undelivered Attempts
			900876210 -- PCA Total Demands
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM > PT_LIST.SURG_STOP_DT_TM
), PCA_PIVOT AS (
	SELECT * FROM PCA_DATA
	PIVOT(
		MIN(RESULT_VAL) FOR EVENT IN (
			'PCA Drug' AS DRUG,
			'PCA Loading Dose' AS LOADING_DOSE,
			'PCA Continuous Rate Dose' AS CONT_RATE,
			'PCA Clinician Bolus' AS BOLUS,
			'PCA Clinician Bolus Unit' AS BOLUS_UNIT,
			'PCA Demand Dose' AS DEMAND_DOSE,
			'PCA Demand Dose Unit' AS DOSE_UNIT,
			'PCA Doses Delivered' AS DOSES_DELIVERED
		)
	)
), PCA_CALC AS (
	SELECT
		PCA_PIVOT.*,
		--((LEAD(EVENT_END_DT_TM, 1, EVENT_END_DT_TM) OVER (PARTITION BY ENCNTR_ID ORDER BY EVENT_END_DT_TM)) - EVENT_END_DT_TM) * 24 AS DURATION,
		CASE
			WHEN DOSE_UNIT = 'milligrams' THEN 
				(DEMAND_DOSE * DOSES_DELIVERED) + NVL(LOADING_DOSE, 0) + NVL(BOLUS, 0) + 
				(NVL(CONT_RATE, 0) * ((LEAD(EVENT_END_DT_TM, 1, EVENT_END_DT_TM) OVER (PARTITION BY ENCNTR_ID ORDER BY EVENT_END_DT_TM)) - EVENT_END_DT_TM))
		END AS DOSE_MG,
		CASE
			WHEN REGEXP_INSTR(LOWER(DRUG), 'hydromorphone') > 0 THEN 20
			WHEN REGEXP_INSTR(LOWER(DRUG), 'morphine') > 0 THEN 3
		END AS ORAL_MME_CONVERSION
	FROM 
		PCA_PIVOT
), PCA_MME AS (
	SELECT 
		PCA_CALC.*,
		DOSE_MG * ORAL_MME_CONVERSION AS ORAL_MME
	FROM
		PCA_CALC
), PCA_TOTALS AS (
	SELECT
		PCA_MME.ENCNTR_ID,
		SUM(PCA_MME.ORAL_MME) AS PCA_MME_TOTAL
	FROM 
		PCA_MME
	GROUP BY
		PCA_MME.ENCNTR_ID
), PT_LOS AS (
	SELECT
		PT_LIST.ALIAS,
		PT_LIST.ENCNTR_ID,
		PT_LIST.DISCH_DT_TM,
		MIN(PT_LIST.SURG_STOP_DT_TM) AS SURG_STOP_DT_TM
	FROM
		PT_LIST
	GROUP BY
		PT_LIST.ALIAS,
		PT_LIST.ENCNTR_ID,
		PT_LIST.DISCH_DT_TM
)

SELECT 
	PT_LOS.ALIAS AS FIN,
	PT_LOS.DISCH_DT_TM - PT_LOS.SURG_STOP_DT_TM AS LOS_AFTER_SURGERY,
	MME_TOTALS.INTERMIT_MME_TOTAL,
	PCA_TOTALS.PCA_MME_TOTAL,
	NVL(MME_TOTALS.INTERMIT_MME_TOTAL, 0) + NVL(PCA_TOTALS.PCA_MME_TOTAL, 0) AS MME_TOTAL,
	(NVL(MME_TOTALS.INTERMIT_MME_TOTAL, 0) + NVL(PCA_TOTALS.PCA_MME_TOTAL, 0)) / (PT_LOS.DISCH_DT_TM - PT_LOS.SURG_STOP_DT_TM) AS MME_PER_DAY
FROM
	MME_TOTALS,
	PCA_TOTALS,
	PT_LOS
WHERE
	PT_LOS.ENCNTR_ID = MME_TOTALS.ENCNTR_ID
	AND PT_LOS.ENCNTR_ID = PCA_TOTALS.ENCNTR_ID(+)
WITH MED_PTS AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		'TRUE' AS INPT_MED
	FROM
		CE_MED_RESULT,
		CLINICAL_EVENT,
		ENCNTR_LOC_HIST,
		ENCOUNTER,
		PERSON
	WHERE
		CLINICAL_EVENT.EVENT_CD IN (
			37557136, -- haloperidol
			37557716, -- olanzapine
			37557952, -- quetiapine
			37558381 -- ziprasidone
		) 
		AND CLINICAL_EVENT.EVENT_END_DT_TM BETWEEN
			pi_to_gmt(
				TO_DATE(
					@Prompt('Enter begin date', 'D', , mono, free, persistent, {'07/01/2019 00:00:00'}, User:0), 
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				), 
				'America/Chicago'
			)
			AND pi_to_gmt(
				TO_DATE(
					@Prompt('Enter end date', 'D', , mono, free, persistent, {'7/01/2020 00:00:00'}, User:1), 
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				) - 1/86400, 
				'America/Chicago'
			)
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND CLINICAL_EVENT.EVENT_ID = CE_MED_RESULT.EVENT_ID
		AND CE_MED_RESULT.ADMIN_DOSAGE > 0
		AND CE_MED_RESULT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND CLINICAL_EVENT.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
		AND CLINICAL_EVENT.PERSON_ID = PERSON.PERSON_ID
		AND TRUNC(((pi_from_gmt(ENCOUNTER.REG_DT_TM, 'America/Chicago')) - PERSON.BIRTH_DT_TM) / 365.25, 0) >= 65
		AND CLINICAL_EVENT.ENCNTR_ID = ENCNTR_LOC_HIST.ENCNTR_ID
		AND ENCNTR_LOC_HIST.BEG_EFFECTIVE_DT_TM <= CLINICAL_EVENT.EVENT_END_DT_TM
		AND ENCNTR_LOC_HIST.TRANSACTION_DT_TM = (
			SELECT MAX(ELH.TRANSACTION_DT_TM)
			FROM ENCNTR_LOC_HIST ELH
			WHERE
				CLINICAL_EVENT.ENCNTR_ID = ELH.ENCNTR_ID
				AND ELH.TRANSACTION_DT_TM <= CLINICAL_EVENT.EVENT_END_DT_TM
		)
		AND ENCNTR_LOC_HIST.END_EFFECTIVE_DT_TM >= CLINICAL_EVENT.EVENT_END_DT_TM
		AND ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD IN (
			1846341943, -- HH 3CP
			3955, -- HH 4WCP
			265179687 -- HH ACE
		)
), DISCH_RX AS (
	SELECT DISTINCT
		ORDERS.ENCNTR_ID,
		'TRUE' AS DISCH_RX
	FROM
		ENCOUNTER,
		ORDERS
	WHERE
		ORDERS.CATALOG_CD IN (
			9902748, -- haloperidol
			9912119, -- OLANZapine
			9912616, -- QUEtiapine
			11732705 -- ziprasidone
		)
		AND ORDERS.ORIG_ORDER_DT_TM BETWEEN
			pi_to_gmt(
				TO_DATE(
					@Prompt('Enter begin date', 'D', , mono, free, persistent, {'07/01/2019 00:00:00'}, User:0), 
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				), 
				'America/Chicago'
			)
			AND pi_to_gmt(
				TO_DATE(
					@Prompt('Enter end date', 'D', , mono, free, persistent, {'7/01/2020 00:00:00'}, User:1), 
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				) - 1/86400, 
				'America/Chicago'
			)
		AND ORDERS.ORIG_ORD_AS_FLAG = 1 -- Prescription/Discharge Order
		AND ORDERS.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
		AND ENCOUNTER.LOC_NURSE_UNIT_CD IN (
			1846341943, -- HH 3CP
			3955, -- HH 4WCP
			265179687 -- HH ACE
		)
), PATIENTS AS (
	SELECT
		COALESCE(MED_PTS.ENCNTR_ID, DISCH_RX.ENCNTR_ID) AS ENCNTR_ID,
		MED_PTS.INPT_MED,
		DISCH_RX.DISCH_RX
	FROM
		MED_PTS FULL OUTER JOIN DISCH_RX ON MED_PTS.ENCNTR_ID = DISCH_RX.ENCNTR_ID
), ICD_CODES AS (
	SELECT DISTINCT
		PATIENTS.ENCNTR_ID,
		NOMENCLATURE.SOURCE_IDENTIFIER AS ICD_10_CODE,
		NOMENCLATURE.SOURCE_STRING,
		'TRUE' AS DIAGNOSIS
	FROM
		DIAGNOSIS,
		NOMENCLATURE,
		PATIENTS
	WHERE
		PATIENTS.ENCNTR_ID = DIAGNOSIS.ENCNTR_ID
		AND DIAGNOSIS.DIAG_TYPE_CD = 26244 -- Final
		AND DIAGNOSIS.NOMENCLATURE_ID = NOMENCLATURE.NOMENCLATURE_ID
		AND REGEXP_INSTR(NOMENCLATURE.SOURCE_IDENTIFIER, '^R41.0|^G93.9|^G93.40|^G93.41') > 0 
		AND NOMENCLATURE.SOURCE_VOCABULARY_CD = 641836527 -- ICD-10-CM
		AND NOMENCLATURE.PRINCIPLE_TYPE_CD = 751 -- Disease or Syndrome
), ICD_PIVOT AS (
	SELECT * FROM ICD_CODES
	PIVOT(
		MIN(DIAGNOSIS) FOR ICD_10_CODE IN (
			'R41.0' AS DELIRIUM,
			'G93.9' AS ENCEPH,
			'G93.40' AS ACUTE_ENCEPH,
			'G93.41' AS MET_ENCEPH
		)
	)
)

SELECT
	PATIENTS.ENCNTR_ID,
	ENCNTR_ALIAS.ALIAS AS FIN,
	PATIENTS.INPT_MED,
	PATIENTS.DISCH_RX,
	ICD_PIVOT.DELIRIUM,
	ICD_PIVOT.ENCEPH,
	ICD_PIVOT.ACUTE_ENCEPH,
	ICD_PIVOT.MET_ENCEPH
FROM
	ENCNTR_ALIAS,
	ICD_PIVOT,
	PATIENTS
WHERE
	PATIENTS.ENCNTR_ID = ICD_PIVOT.ENCNTR_ID(+)
	AND PATIENTS.ENCNTR_ID = ENCNTR_ALIAS.ENCNTR_ID
	AND ENCNTR_ALIAS.ENCNTR_ALIAS_TYPE_CD = 619 -- FIN NBR
	AND ENCNTR_ALIAS.ACTIVE_IND = 1


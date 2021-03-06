WITH DOSES AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.PERSON_ID,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		CLINICAL_EVENT.EVENT_ID
	FROM
		CE_MED_RESULT,
		CLINICAL_EVENT,
		ENCNTR_LOC_HIST
		-- ENCOUNTER
		-- PERSON
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
		-- AND CLINICAL_EVENT.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
		-- AND CLINICAL_EVENT.PERSON_ID = PERSON.PERSON_ID
		-- AND TRUNC(((pi_from_gmt(ENCOUNTER.REG_DT_TM, 'America/Chicago')) - PERSON.BIRTH_DT_TM) / 365.25, 0) >= 65
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
			4356, -- HH 6EJP
			1542800, -- HH 6WJP
			16163788, -- HH 8NJP
			8667295, -- HH 3JP
			2428498395, -- HH S1MU
			3224987147, -- HH S SITU
			3224987399, -- HH S SIMU
			3224988029, -- HH S OTAC
			1846341943, -- HH 3CP
			1846342787, -- HH 3CIM
			3955, -- HH 4WCP
			265179687 -- HH ACE
		)
), MED_PTS AS (
	SELECT DISTINCT
		ENCNTR_ID,
		'TRUE' AS INPT_MED
	FROM
		DOSES
), ALL_DOSES AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.PERSON_ID,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		CLINICAL_EVENT.EVENT_ID
	FROM
		CE_MED_RESULT,
		CLINICAL_EVENT,
		DOSES
	WHERE
		DOSES.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 158 -- MED
		AND DOSES.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_CD IN (
			37557136, -- haloperidol
			37557716, -- olanzapine
			37557952, -- quetiapine
			37558381 -- ziprasidone
		) 
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND CLINICAL_EVENT.EVENT_ID = CE_MED_RESULT.EVENT_ID
		AND CE_MED_RESULT.ADMIN_DOSAGE > 0
		AND CE_MED_RESULT.VALID_UNTIL_DT_TM > DATE '2099-12-31'	
), FIRST_MED AS (
	SELECT
		ENCNTR_ID,
		MIN(EVENT_END_DT_TM) AS FIRST_DOSE_DATETIME
	FROM
		ALL_DOSES
	GROUP BY 
		ENCNTR_ID
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
			4356, -- HH 6EJP
			1542800, -- HH 6WJP
			16163788, -- HH 8NJP
			8667295, -- HH 3JP
			2428498395, -- HH S1MU
			3224987147, -- HH S SITU
			3224987399, -- HH S SIMU
			3224988029, -- HH S OTAC
			1846341943, -- HH 3CP
			1846342787, -- HH 3CIM
			3955, -- HH 4WCP
			265179687 -- HH ACE
		)
), RESTRAINT_EVENTS AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.PERSON_ID,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		CLINICAL_EVENT.EVENT_ID
	FROM
		CLINICAL_EVENT,
		ENCNTR_LOC_HIST
		-- ENCOUNTER
		-- PERSON
	WHERE
		CLINICAL_EVENT.EVENT_CD IN (
			381099326, -- Reason for Restraint-Non-Behavioral
			381099364, -- Reason for Restraint-Behavioral
			622910577, -- Reason for Restraint-Violent
			622916513, -- Reason for Restraint-Non-Violent
			680274275, -- NVR Reason for Restraint
			681197770 -- VR Reason for Restraint
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
			4356, -- HH 6EJP
			1542800, -- HH 6WJP
			16163788, -- HH 8NJP
			8667295, -- HH 3JP
			2428498395, -- HH S1MU
			3224987147, -- HH S SITU
			3224987399, -- HH S SIMU
			3224988029, -- HH S OTAC
			1846341943, -- HH 3CP
			1846342787, -- HH 3CIM
			3955, -- HH 4WCP
			265179687 -- HH ACE
		)
), RESTRAINTS AS (
	SELECT DISTINCT
		ENCNTR_ID,
		'TRUE' AS RESTRAINT
	FROM
		RESTRAINT_EVENTS
), ALL_RESTRAINTS AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.PERSON_ID,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		CLINICAL_EVENT.EVENT_ID
	FROM
		CLINICAL_EVENT,
		RESTRAINT_EVENTS
	WHERE
		RESTRAINT_EVENTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND RESTRAINT_EVENTS.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_CD IN (
			381099326, -- Reason for Restraint-Non-Behavioral
			381099364, -- Reason for Restraint-Behavioral
			622910577, -- Reason for Restraint-Violent
			622916513, -- Reason for Restraint-Non-Violent
			680274275, -- NVR Reason for Restraint
			681197770 -- VR Reason for Restraint
		) 
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
), FIRST_RESTR AS (
	SELECT
		ENCNTR_ID,
		MIN(EVENT_END_DT_TM) AS FIRST_RESTRAINT_DATETIME
	FROM
		ALL_RESTRAINTS
	GROUP BY 
		ENCNTR_ID
), SITTERS AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		'TRUE' AS SITTER
	FROM
		CLINICAL_EVENT,
		ENCNTR_LOC_HIST
	WHERE
		CLINICAL_EVENT.EVENT_CD = 134604033 -- 1:1 Sitter/Staff-Maint Contact w/Pt
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
			4356, -- HH 6EJP
			1542800, -- HH 6WJP
			16163788, -- HH 8NJP
			8667295, -- HH 3JP
			2428498395, -- HH S1MU
			3224987147, -- HH S SITU
			3224987399, -- HH S SIMU
			3224988029, -- HH S OTAC
			1846341943, -- HH 3CP
			1846342787, -- HH 3CIM
			3955, -- HH 4WCP
			265179687 -- HH ACE
		)
), PTS_MEDS AS (
	SELECT
		COALESCE(MED_PTS.ENCNTR_ID, DISCH_RX.ENCNTR_ID) AS ENCNTR_ID,
		MED_PTS.INPT_MED,
		DISCH_RX.DISCH_RX
	FROM
		MED_PTS FULL OUTER JOIN DISCH_RX ON MED_PTS.ENCNTR_ID = DISCH_RX.ENCNTR_ID
), PTS_REST AS (
	SELECT
		COALESCE(RESTRAINTS.ENCNTR_ID, SITTERS.ENCNTR_ID) AS ENCNTR_ID,
		RESTRAINTS.RESTRAINT,
		SITTERS.SITTER
	FROM
		RESTRAINTS FULL OUTER JOIN SITTERS ON RESTRAINTS.ENCNTR_ID = SITTERS.ENCNTR_ID
), PATIENTS AS (
	SELECT
		COALESCE(PTS_MEDS.ENCNTR_ID, PTS_REST.ENCNTR_ID) AS ENCNTR_ID,
		PTS_MEDS.INPT_MED,
		PTS_MEDS.DISCH_RX,
		PTS_REST.RESTRAINT,
		PTS_REST.SITTER
	FROM
		PTS_MEDS FULL OUTER JOIN PTS_REST ON PTS_MEDS.ENCNTR_ID = PTS_REST.ENCNTR_ID
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
), HOME_MEDS AS (
	SELECT DISTINCT
		PATIENTS.ENCNTR_ID,
		pi_get_cv_display(ORDERS.CATALOG_CD) AS HOME_MED,
		'TRUE' AS MED
	FROM
		ORDERS,
		PATIENTS
	WHERE
		PATIENTS.ENCNTR_ID = ORDERS.ENCNTR_ID
		AND ORDERS.CATALOG_CD IN (
			9902748, -- haloperidol
			9912119, -- OLANZapine
			9912616, -- QUEtiapine
			11732705 -- ziprasidone
		)
		AND ORDERS.ORIG_ORD_AS_FLAG = 2 -- Recorded/Home Meds
), HOME_MEDS_PIVOT AS (
	SELECT * FROM HOME_MEDS
	PIVOT(
		MIN(MED) FOR HOME_MED IN (
			'haloperidol' AS HM_HALOPERIDOL,
			'OLANZapine' AS HM_OLANZAPINE,
			'QUEtiapine' AS HM_QUETIAPINE,
			'ziprasidone' AS HM_ZIPRASIDONE
		)
	)
), ICU_STAY AS (
	SELECT 
		PATIENTS.ENCNTR_ID,
		'TRUE' AS ICU_STAY
	FROM 
		ENCNTR_LOC_HIST,
		PATIENTS
	WHERE
		PATIENTS.ENCNTR_ID = ENCNTR_LOC_HIST.ENCNTR_ID
		AND ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD IN (
			4122, -- HH MICU
			4137, -- HH CCU
			5441, -- HH STIC
			5541, -- HH CVICU
			18116572, -- HH 8WJP
			283905037, -- HH 7J
			1993318732, -- HH HFIC
			2369096643, -- HH TSCU
			2041371668, -- HH NVIC
			3311213379, -- HH TICU
			3224987721, -- HH S STIC
			3224986803, -- HH S BURN
			3224988589, -- HH S SHIC
			3224988925, -- HH S TSIC
			3392290381 -- HH S MICU
		)
)

SELECT
	PATIENTS.ENCNTR_ID,
	ENCNTR_ALIAS.ALIAS AS FIN,
	TRUNC(((pi_from_gmt(ENCOUNTER.REG_DT_TM, 'America/Chicago')) - PERSON.BIRTH_DT_TM) / 365.25, 0) AS AGE,
	pi_get_cv_display(PERSON.SEX_CD) AS SEX,
	pi_get_cv_display(PERSON.RACE_CD) AS RACE,
	ENCOUNTER.DISCH_DT_TM - ENCOUNTER.REG_DT_TM AS LOS,
	pi_get_cv_display(ENCOUNTER.LOC_NURSE_UNIT_CD) AS DISCH_NURSE_UNIT,
	pi_get_cv_display(ENCOUNTER.DISCH_DISPOSITION_CD) AS DISCH_DISPOSITION,
	pi_get_cv_display(ENCOUNTER.ENCNTR_TYPE_CLASS_CD) AS ENCNTR_TYPE_CLASS,
	ICU_STAY.ICU_STAY,
	PATIENTS.INPT_MED,
	PATIENTS.DISCH_RX,
	PATIENTS.RESTRAINT,
	PATIENTS.SITTER,
	FIRST_MED.FIRST_DOSE_DATETIME - ENCOUNTER.REG_DT_TM AS ADMIT_DOSE_DAYS,
	FIRST_MED.FIRST_DOSE_DATETIME - ENCOUNTER.BEG_EFFECTIVE_DT_TM AS ARRIVE_DOSE_DAYS,
	FIRST_RESTR.FIRST_RESTRAINT_DATETIME - ENCOUNTER.REG_DT_TM AS ADMIT_RESTRAINT_DAYS,
	FIRST_RESTR.FIRST_RESTRAINT_DATETIME - ENCOUNTER.BEG_EFFECTIVE_DT_TM AS ARRIVE_RESTRAINT_DAYS,
	ICD_PIVOT.DELIRIUM,
	ICD_PIVOT.ENCEPH,
	ICD_PIVOT.ACUTE_ENCEPH,
	ICD_PIVOT.MET_ENCEPH,
	HOME_MEDS_PIVOT.HM_HALOPERIDOL,
	HOME_MEDS_PIVOT.HM_OLANZAPINE,
	HOME_MEDS_PIVOT.HM_QUETIAPINE,
	HOME_MEDS_PIVOT.HM_ZIPRASIDONE
FROM
	ENCNTR_ALIAS,
	ENCOUNTER,
	FIRST_MED,
	FIRST_RESTR,
	HOME_MEDS_PIVOT,
	ICD_PIVOT,
	ICU_STAY,
	PATIENTS,
	PERSON
WHERE
	PATIENTS.ENCNTR_ID = ICD_PIVOT.ENCNTR_ID(+)
	AND PATIENTS.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
	AND ENCOUNTER.PERSON_ID = PERSON.PERSON_ID
	AND PATIENTS.ENCNTR_ID = FIRST_MED.ENCNTR_ID(+)
	AND PATIENTS.ENCNTR_ID = FIRST_RESTR.ENCNTR_ID(+)
	AND PATIENTS.ENCNTR_ID = HOME_MEDS_PIVOT.ENCNTR_ID(+)
	AND PATIENTS.ENCNTR_ID = ICU_STAY.ENCNTR_ID(+)
	AND PATIENTS.ENCNTR_ID = ENCNTR_ALIAS.ENCNTR_ID
	AND ENCNTR_ALIAS.ENCNTR_ALIAS_TYPE_CD = 619 -- FIN NBR
	AND ENCNTR_ALIAS.ACTIVE_IND = 1


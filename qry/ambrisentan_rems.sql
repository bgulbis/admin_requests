WITH DOSES AS (
	SELECT DISTINCT
		ENCNTR_ALIAS.ALIAS AS FIN,
		CLINICAL_EVENT.ENCNTR_ID,
		TRUNC((TRUNC(pi_from_gmt(ENCOUNTER.REG_DT_TM, 'America/Chicago')) - TRUNC(pi_from_gmt(PERSON.BIRTH_DT_TM, 'America/Chicago'))) / 365.25, 0) AS AGE,
		pi_get_cv_display(PERSON.SEX_CD) AS SEX,
		pi_from_gmt(ENCOUNTER.REG_DT_TM, 'America/Chciago') AS ADMIT_DATETIME,
		pi_from_gmt(ENCOUNTER.DISCH_DT_TM, 'America/Chicago') AS DISCH_DATETIME,
		CLINICAL_EVENT.EVENT_ID,
		pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, 'America/Chicago') AS EVENT_DATETIME,
		pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS EVENT,
		CLINICAL_EVENT.RESULT_VAL
	FROM
		CLINICAL_EVENT,
		ENCNTR_ALIAS,
		ENCOUNTER,
		PERSON
	WHERE
		CLINICAL_EVENT.EVENT_CD IN (
			259555330, -- ambrisentan
			824311744, -- Ambrisentan Prescribing Certification
			3844277695, -- Ambrisentan Continuation of Therapy
			3987676597, -- ambrisentan 1 mg/mL 1 mL oral SUSP
			4079151139 -- Ambrisentan REMS Qualification
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM BETWEEN
			pi_to_gmt(
				TO_DATE(
					@Prompt('Enter begin date', 'D', , mono, free, persistent, {'01/01/2023 00:00:00'}, User:0), 
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				), 
				pi_time_zone(1, @Variable('BOUSER'))
			)
			AND pi_to_gmt(
				TO_DATE(
					@Prompt('Enter end date', 'D', , mono, free, persistent, {'01/01/2024 00:00:00'}, User:1), 
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				) - 1/86400, 
				pi_time_zone(1, @Variable('BOUSER'))
			)
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND CLINICAL_EVENT.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
		AND ENCOUNTER.LOC_FACILITY_CD IN (
			3310, -- HH HERMANN
			3796, -- HC Childrens
			3821, -- HH Clinics
			3822, -- HH Trans Care
			3823 -- HH Rehab		
		)
		AND CLINICAL_EVENT.PERSON_ID = PERSON.PERSON_ID
		AND CLINICAL_EVENT.ENCNTR_ID = ENCNTR_ALIAS.ENCNTR_ID
		AND ENCNTR_ALIAS.ENCNTR_ALIAS_TYPE_CD = 619 -- FIN NBR
		AND ENCNTR_ALIAS.ACTIVE_IND = 1
), DOSES_PIVOT AS (
	SELECT * FROM DOSES
	PIVOT(
		MIN(RESULT_VAL) FOR EVENT IN (
			'ambrisentan' AS DOSE,
			'Ambrisentan Prescribing Certification' AS PRESCRIBING_CERTIFICATION,
			'Ambrisentan Continuation of Therapy' AS CONTINUE_THERAPY,
			'Ambrisentan REMS Qualification' AS REMS_QUALIFICATION
		)
	)		
)

SELECT * FROM DOSES_PIVOT
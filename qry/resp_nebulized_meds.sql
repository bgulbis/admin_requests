WITH DOSES AS (
	SELECT DISTINCT
		CLINICAL_EVENT.EVENT_CD,
		pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS EVENT,
		CE_MED_RESULT.ADMIN_ROUTE_CD,
		pi_get_cv_display(CE_MED_RESULT.ADMIN_ROUTE_CD) AS ADMIN_ROUTE
	FROM
		CE_MED_RESULT,
		CLINICAL_EVENT,
		ENCOUNTER
	WHERE
		ENCOUNTER.LOC_FACILITY_CD IN (
			3310, -- HH HERMANN
			3796, -- HC Childrens
			3821, -- HH Clinics
			3822, -- HH Trans Care
			3823 -- HH Rehab
		)
		AND ENCOUNTER.REG_DT_TM BETWEEN 
			pi_to_gmt(
				TO_DATE(
					@Prompt('Enter begin date', 'D', , mono, free, persistent, {'07/01/2021 00:00:00'}, User:0), 
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				), 
				'America/Chicago'
			)
			AND pi_to_gmt(
				TO_DATE(
					@Prompt('Enter end date', 'D', , mono, free, persistent, {'01/01/2022 00:00:00'}, User:1), 
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				), 
				'America/Chicago'
			) - 1/86400
		AND ENCOUNTER.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 158 -- MED
		AND ENCOUNTER.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		-- AND CLINICAL_EVENT.EVENT_CD = 37557146 -- heparin
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND CLINICAL_EVENT.EVENT_ID = CE_MED_RESULT.EVENT_ID
		AND CE_MED_RESULT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
)

SELECT 
	EVENT,
	EVENT_CD
FROM DOSES
WHERE
	ADMIN_ROUTE_CD IN (
		9022883, -- INHALER
		9022892 -- NEB
	)
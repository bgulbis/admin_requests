SELECT DISTINCT
	ENCOUNTER.PERSON_ID,
	ENCNTR_ALIAS.ALIAS AS FIN,
	pi_from_gmt(ENCOUNTER.REG_DT_TM, 'America/Chicago') AS ADMIT_DATETIME,
	pi_from_gmt(ENCOUNTER.DISCH_DT_TM, 'America/Chicago') AS DISCH_DATETIME,
	pi_get_cv_display(ENCOUNTER.LOC_NURSE_UNIT_CD) AS DISCH_NURSE_UNIT,
	pi_get_cv_display(ENCOUNTER.ENCNTR_TYPE_CLASS_CD) AS ENCNTR_TYPE_CLASS
FROM
	DIAGNOSIS,
	ENCNTR_ALIAS,
	ENCOUNTER,
	NOMENCLATURE
WHERE
	ENCOUNTER.ORGANIZATION_ID = 1 -- Memorial Hermann Hospital
	AND ENCOUNTER.DISCH_DT_TM BETWEEN 
		pi_to_gmt(
			TO_DATE(
				@Prompt('Enter begin date', 'D', , mono, free, persistent, {'07/01/2020 00:00:00'}, User:0), 
				pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
			), 
			pi_time_zone(1, 'America/Chicago')
		)
		AND pi_to_gmt(
			TO_DATE(
				@Prompt('Enter end date', 'D', , mono, free, persistent, {'06/01/2022 00:00:00'}, User:1), 
				pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
			) - 1/86400, 
			pi_time_zone(1, 'America/Chicago')
		)
	AND ENCOUNTER.LOC_FACILITY_CD IN (
		3310, -- HH HERMANN
		3796, -- HC Childrens
		3821, -- HH Clinics
		3822, -- HH Trans Care
		3823 -- HH Rehab
		-- 1099966301 -- HH Oncology TMC	
	)
	AND ENCOUNTER.ENCNTR_ID = DIAGNOSIS.ENCNTR_ID
	AND DIAGNOSIS.DIAG_TYPE_CD = 26244 -- Final
	-- AND DIAGNOSIS.DIAG_PRIORITY = 1
	AND DIAGNOSIS.NOMENCLATURE_ID = NOMENCLATURE.NOMENCLATURE_ID
	AND REGEXP_INSTR(NOMENCLATURE.SOURCE_IDENTIFIER, '^M31.1') > 0
	AND NOMENCLATURE.SOURCE_VOCABULARY_CD = 641836527 -- ICD-10-CM
	AND NOMENCLATURE.PRINCIPLE_TYPE_CD = 751 -- Disease or Syndrome
	AND ENCOUNTER.ENCNTR_ID = ENCNTR_ALIAS.ENCNTR_ID
    AND ENCNTR_ALIAS.ENCNTR_ALIAS_TYPE_CD = 619 -- FIN NBR
    AND ENCNTR_ALIAS.ACTIVE_IND = 1
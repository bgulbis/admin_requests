WITH DIAG_CODE AS (
	SELECT DISTINCT
		NOMENCLATURE.NOMENCLATURE_ID
	FROM
		NOMENCLATURE
	WHERE
		REGEXP_INSTR(NOMENCLATURE.SOURCE_IDENTIFIER, '^I21') > 0 
		AND NOMENCLATURE.SOURCE_VOCABULARY_CD = 641836527 -- ICD-10-CM
		AND NOMENCLATURE.PRINCIPLE_TYPE_CD = 751 -- Disease or Syndrome
), PROC_CODE AS (
	SELECT DISTINCT
		NOMENCLATURE.NOMENCLATURE_ID
	FROM
		NOMENCLATURE
	WHERE
		REGEXP_INSTR(NOMENCLATURE.SOURCE_IDENTIFIER, '^027[0-3]') > 0 
		AND NOMENCLATURE.SOURCE_VOCABULARY_CD = 641836522 -- ICD-10-PCS
		AND NOMENCLATURE.PRINCIPLE_TYPE_CD = 761 -- Procedure
), STEMI_PTS AS (
	SELECT DISTINCT
		ENCOUNTER.ENCNTR_ID,
		-- ENCOUNTER.PERSON_ID,
		ENCOUNTER.REG_DT_TM,
		ENCOUNTER.DISCH_DT_TM
	FROM
		DIAG_CODE,
		DIAGNOSIS,
		ENCOUNTER
	WHERE
		ENCOUNTER.ORGANIZATION_ID = 1 -- Memorial Hermann Hospital
		AND ENCOUNTER.REG_DT_TM BETWEEN 
			pi_to_gmt(
				TO_DATE(
					@Prompt('Enter begin date', 'D', , mono, free, persistent, {'01/01/1800 00:00:00'}, User:0), 
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				), 
				pi_time_zone(1, @Variable('BOUSER'))
			)
			AND pi_to_gmt(
				TO_DATE(
					@Prompt('Enter end date', 'D', , mono, free, persistent, {'01/01/1800 00:00:00'}, User:1), 
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				) - 1/86400, 
				pi_time_zone(1, @Variable('BOUSER'))
			)
		AND ENCOUNTER.LOC_FACILITY_CD = 3310 -- HH HERMANN
		AND ENCOUNTER.ENCNTR_ID = DIAGNOSIS.ENCNTR_ID
		AND DIAGNOSIS.DIAG_TYPE_CD = 26244 -- Final
		-- AND DIAGNOSIS.DIAG_PRIORITY = 1
		AND DIAGNOSIS.NOMENCLATURE_ID = DIAG_CODE.NOMENCLATURE_ID
), CATH_PTS AS (
	SELECT DISTINCT
		ENCOUNTER.ENCNTR_ID,
		-- ENCOUNTER.PERSON_ID,
		ENCOUNTER.REG_DT_TM,
		ENCOUNTER.DISCH_DT_TM,
		PROCEDURE.PROC_DT_TM
	FROM
		ENCOUNTER,
		PROC_CODE,
		PROCEDURE
	WHERE
		ENCOUNTER.ORGANIZATION_ID = 1 -- Memorial Hermann Hospital
		AND ENCOUNTER.REG_DT_TM BETWEEN 
			pi_to_gmt(
				TO_DATE(
					@Prompt('Enter begin date', 'D', , mono, free, persistent, {'01/01/1800 00:00:00'}, User:0), 
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				), 
				pi_time_zone(1, @Variable('BOUSER'))
			)
			AND pi_to_gmt(
				TO_DATE(
					@Prompt('Enter end date', 'D', , mono, free, persistent, {'01/01/1800 00:00:00'}, User:1), 
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				) - 1/86400, 
				pi_time_zone(1, @Variable('BOUSER'))
			)
		AND ENCOUNTER.LOC_FACILITY_CD = 3310 -- HH HERMANN
		AND ENCOUNTER.ENCNTR_ID = PROCEDURE.ENCNTR_ID
		AND PROCEDURE.NOMENCLATURE_ID = PROC_CODE.NOMENCLATURE_ID 
), PATIENTS AS (
	SELECT
		STEMI_PTS.ENCNTR_ID,
		pi_to_gmt(TRUNC(STEMI_PTS.REG_DT_TM, 'DAY'), pi_time_zone(2, @Variable('BOUSER'))) AS ADMIT_WEEK,
		CASE
			WHEN CATH_PTS.PROC_DT_TM IS NOT NULL THEN 1
			ELSE 0
		END AS PCI
	FROM
		CATH_PTS,
		STEMI_PTS
	WHERE
		STEMI_PTS.ENCNTR_ID = CATH_PTS.ENCNTR_ID(+)
)

SELECT 
	ADMIT_WEEK AS WEEK,
	COUNT(ENCNTR_ID) AS STEMI_PTS,
	SUM(PCI) AS NUM_CATHED
FROM
	PATIENTS
GROUP BY
	ADMIT_WEEK
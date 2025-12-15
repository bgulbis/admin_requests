SELECT DISTINCT
	CLINICAL_EVENT.ENCNTR_ID,
	TRUNC((TRUNC(pi_from_gmt(ENCOUNTER.REG_DT_TM, 'America/Chicago')) - TRUNC(pi_from_gmt(PERSON.BIRTH_DT_TM, 'America/Chicago'))) / 365.25, 0) AS AGE,
	pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, 'America/Chicago') AS DOSE_DATETIME,
	CLINICAL_EVENT.EVENT_ID,
	pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS MEDICATION,
	pi_get_cv_display(ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD) AS NURSE_UNIT
FROM
	CE_MED_RESULT,
	CLINICAL_EVENT,
	ENCNTR_LOC_HIST,
	ENCOUNTER,
	PERSON
WHERE
	CLINICAL_EVENT.EVENT_CD IN (
		37557133, -- haemophilus b conjugate vaccine
		94132360, -- haemophilus b conjugate (HbOC) vaccine
		94132361, -- haemophilus b conjugate (PRP-T) vaccine
		210759315 -- haemophilus b conjugate (PRP-OMP) vacc
	)
	AND CLINICAL_EVENT.EVENT_END_DT_TM BETWEEN
		pi_to_gmt(
			TO_DATE(
				@Prompt('Enter begin date', 'D', , mono, free, persistent, {'01/01/2022 00:00:00'}, User:0), 
				pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
			), 
			'America/Chicago'
		)
		AND pi_to_gmt(
			TO_DATE(
				@Prompt('Enter end date', 'D', , mono, free, persistent, {'01/01/2023 00:00:00'}, User:1), 
				pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
			) - 1/86400, 
			'America/Chicago'
		)
	AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
	AND CLINICAL_EVENT.EVENT_ID = CE_MED_RESULT.EVENT_ID
	AND CE_MED_RESULT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
	AND CLINICAL_EVENT.ENCNTR_ID = ENCNTR_LOC_HIST.ENCNTR_ID
	AND ENCNTR_LOC_HIST.BEG_EFFECTIVE_DT_TM <= CLINICAL_EVENT.EVENT_END_DT_TM
	AND ENCNTR_LOC_HIST.TRANSACTION_DT_TM = (
		SELECT MAX(ELH.TRANSACTION_DT_TM)
		FROM ENCNTR_LOC_HIST ELH
		WHERE
			CLINICAL_EVENT.ENCNTR_ID = ELH.ENCNTR_ID
			AND ELH.TRANSACTION_DT_TM <= CLINICAL_EVENT.EVENT_END_DT_TM
			AND ELH.ACTIVE_IND = 1
	)
	AND ENCNTR_LOC_HIST.ACTIVE_IND = 1
	AND ENCNTR_LOC_HIST.LOC_FACILITY_CD IN (
		3310, -- HH HERMANN
		3796, -- HC Childrens
		3821, -- HH Clinics
		3822, -- HH Trans Care
		3823 -- HH Rehab		
	)
	-- AND ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD IN (
		-- 1101289, -- HH WC5
		-- 77842455, -- HH WC6N
		-- 923835653, -- HH WCAN
		-- 1150050540 -- HH WCOR
	-- )			
	AND ENCNTR_LOC_HIST.END_EFFECTIVE_DT_TM >= CLINICAL_EVENT.EVENT_END_DT_TM
	AND CLINICAL_EVENT.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
	AND CLINICAL_EVENT.PERSON_ID = PERSON.PERSON_ID

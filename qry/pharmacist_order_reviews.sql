SELECT
	ORDER_REVIEW.ORDER_ID,
	ORDER_REVIEW.ACTION_SEQUENCE,
	ORDER_REVIEW.REVIEW_SEQUENCE,
	pi_from_gmt(ORDER_ACTION.ACTION_DT_TM, 'America/Chicago') AS ACTION_DATETIME,
	pi_from_gmt(ORDER_REVIEW.REVIEW_DT_TM, 'America/Chicago') AS REVIEW_DATETIME,
	pi_from_gmt(TRUNC(ORDER_REVIEW.REVIEW_DT_TM, 'HH'), 'America/Chicago') AS REVIEW_HOUR,
	(ORDER_REVIEW.REVIEW_DT_TM - ORDER_ACTION.ACTION_DT_TM) * 24 * 60 AS ORDER_REVIEW_MIN,
	PRSNL.NAME_FULL_FORMATTED AS PHARMACIST,
	pi_get_cv_display(ORDERS.CATALOG_CD) AS MEDICATION,
	pi_get_cv_display(ORDER_ACTION.ACTION_TYPE_CD) AS ACTION_TYPE,
	pi_get_cv_display(ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD) AS NURSE_UNIT,
	CASE ORDER_REVIEW.REVIEWED_STATUS_FLAG
		WHEN 1 THEN 'Accepted'
		WHEN 2 THEN 'Rejected'
		WHEN 5 THEN 'Reviewed'
	END AS VERIFIED_STATUS
FROM
	ENCNTR_LOC_HIST,
	ORDER_ACTION,
	ORDER_REVIEW,
	ORDERS,
	PRSNL
WHERE
	ORDER_REVIEW.UPDT_DT_TM BETWEEN
		DECODE(
			@Prompt('Choose date range', 'A', {'Yesterday', 'Two Weeks', 'User-defined'}, mono, free, , , User:79),
			'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - 1, 'America/Chicago'),
			'Two Weeks', pi_to_gmt(TRUNC(SYSDATE - 14, 'DAY'), 'America/Chicago'),
			'User-defined', pi_to_gmt(
				TO_DATE(
					@Prompt('Enter begin date (Leave as 01/01/1800 if using a Relative Date)', 'D', , mono, free, persistent, {'01/01/1800 00:00:00'}, User:80),
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				),
				'America/Chicago'
			)
		)
		AND DECODE(
			@Prompt('Choose date range', 'A', {'Yesterday', 'Two Weeks', 'User-defined'}, mono, free, , , User:79),
			'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - 1/86400, 'America/Chicago'),
			'Two Weeks', pi_to_gmt(TRUNC(SYSDATE, 'DAY') - 1/86400, 'America/Chicago'),
			'User-defined', pi_to_gmt(
				TO_DATE(
					@Prompt('Enter end date (Leave as 01/01/1800 if using a Relative Date)', 'D', , mono, free, persistent, {'01/01/1800 23:59:59'}, User:81),
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				),
				'America/Chicago'
			)
		)
	AND ORDER_REVIEW.REVIEW_TYPE_FLAG = 3 -- Pharmacist
	AND ORDER_REVIEW.REVIEWED_STATUS_FLAG IN (1, 2, 5)
	AND ORDER_REVIEW.REVIEW_PERSONNEL_ID <> 1
	AND ORDER_REVIEW.ORDER_ID = ORDERS.ORDER_ID
	AND ORDER_REVIEW.ORDER_ID = ORDER_ACTION.ORDER_ID
	AND ORDER_REVIEW.ACTION_SEQUENCE = ORDER_ACTION.ACTION_SEQUENCE
	AND ORDER_REVIEW.REVIEW_PERSONNEL_ID = PRSNL.PERSON_ID
	AND ORDERS.ENCNTR_ID = ENCNTR_LOC_HIST.ENCNTR_ID
	AND ENCNTR_LOC_HIST.BEG_EFFECTIVE_DT_TM <= ORDER_ACTION.ACTION_DT_TM
	AND ENCNTR_LOC_HIST.TRANSACTION_DT_TM = (
		SELECT MAX(ELH.TRANSACTION_DT_TM)
		FROM ENCNTR_LOC_HIST ELH
		WHERE
			ORDERS.ENCNTR_ID = ELH.ENCNTR_ID
			AND ELH.TRANSACTION_DT_TM <= ORDER_ACTION.ACTION_DT_TM
	)
	AND ENCNTR_LOC_HIST.LOC_FACILITY_CD IN (
		3310, -- HH HERMANN
		3796, -- HC Childrens
		3821, -- HH Clinics
		3822, -- HH Trans Care
		3823, -- HH Rehab
		1099966301 -- HH Oncology TMC
	)
	AND ENCNTR_LOC_HIST.END_EFFECTIVE_DT_TM >= ORDER_ACTION.ACTION_DT_TM

-- //mh.org/public/HER/HER - Pharmacy/Order Actions Report
-- //mh.org/public/HER/HER - Pharmacy/Order Actions Report/Cumulative
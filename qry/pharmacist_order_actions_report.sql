WITH ORD_ACTIONS AS (
	SELECT DISTINCT
		ORDER_ACTION.ORDER_ACTION_ID,
		ORDER_ACTION.ORDER_ID,
		ORDER_ACTION.ACTION_SEQUENCE,
		ORDER_ACTION.ACTION_TYPE_CD,
		ORDER_ACTION.ACTION_DT_TM,
		ORDERS.ENCNTR_ID,
		ORDERS.CATALOG_CD
	FROM
		ORDER_ACTION,
		ORDERS
	WHERE
		ORDER_ACTION.ACTION_DT_TM BETWEEN
		/*
			pi_to_gmt(TRUNC(SYSDATE) - 2, pi_time_zone(2, @Variable('BOUSER')))
			AND pi_to_gmt(TRUNC(SYSDATE) - (1 / 86400), pi_time_zone(2, @Variable('BOUSER')))
		*/
		
			DECODE(
				@Prompt('Choose date range', 'A', {'Yesterday', 'User-defined'}, mono, free, , , User:79),
				'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - 2, pi_time_zone(2, @Variable('BOUSER'))),
				'User-defined', pi_to_gmt(
					TO_DATE(
						@Prompt('Enter begin date (Leave as 01/01/1800 if using a Relative Date)', 'D', , mono, free, persistent, {'01/01/1800 00:00:00'}, User:80),
						pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
					),
					pi_time_zone(1, @Variable('BOUSER')))
			)
			AND DECODE(
				@Prompt('Choose date range', 'A', {'Yesterday', 'User-defined'}, mono, free, , , User:79),
				'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - (1 / 86400), pi_time_zone(2, @Variable('BOUSER'))),
				'User-defined', pi_to_gmt(
					TO_DATE(
						@Prompt('Enter end date (Leave as 01/01/1800 if using a Relative Date)', 'D', , mono, free, persistent, {'01/01/1800 23:59:59'}, User:81),
						pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
					),
					pi_time_zone(1, @Variable('BOUSER')))
			)
		
		AND ORDER_ACTION.ORDER_ID = ORDERS.ORDER_ID
		AND ORDERS.CATALOG_TYPE_CD = 1363 -- Pharmacy
		AND ORDERS.ACTIVITY_TYPE_CD = 378 -- Pharmacy
), PTS AS (
	SELECT DISTINCT
		ORD_ACTIONS.ENCNTR_ID
	FROM
		ORD_ACTIONS
), TMC AS (
	SELECT DISTINCT
		PTS.ENCNTR_ID
	FROM
		ENCOUNTER,
		PTS
	WHERE
		PTS.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
		AND ENCOUNTER.LOC_FACILITY_CD IN (
			3310, -- HH HERMANN
			3796, -- HC Childrens
			3821, -- HH Clinics
			3822, -- HH Trans Care
			3823, -- HH Rehab
			1099966301 -- HH Oncology TMC
		)
), REVIEWS AS (
	SELECT DISTINCT
		ORD_ACTIONS.ACTION_DT_TM,
		ORDER_REVIEW.REVIEW_DT_TM,
		ORD_ACTIONS.CATALOG_CD,
		PRSNL.NAME_FULL_FORMATTED,
		ORD_ACTIONS.ACTION_TYPE_CD,
		ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD,
		ORD_ACTIONS.ORDER_ID,
		ORDER_REVIEW.REVIEWED_STATUS_FLAG
	FROM
		ENCNTR_LOC_HIST,
		ORD_ACTIONS,
		ORDER_REVIEW,
		PRSNL,
		TMC
	WHERE
		ORD_ACTIONS.ENCNTR_ID = TMC.ENCNTR_ID
		AND ORD_ACTIONS.ORDER_ID = ORDER_REVIEW.ORDER_ID
		AND ORD_ACTIONS.ACTION_SEQUENCE = ORDER_REVIEW.ACTION_SEQUENCE
		AND ORDER_REVIEW.REVIEW_TYPE_FLAG = 3 -- Pharmacist
		AND ORDER_REVIEW.REVIEWED_STATUS_FLAG IN (1, 2, 5)
		AND ORDER_REVIEW.REVIEW_PERSONNEL_ID = PRSNL.PERSON_ID
		AND ORD_ACTIONS.ENCNTR_ID = ENCNTR_LOC_HIST.ENCNTR_ID
		AND ENCNTR_LOC_HIST.BEG_EFFECTIVE_DT_TM <= ORD_ACTIONS.ACTION_DT_TM
		AND ENCNTR_LOC_HIST.TRANSACTION_DT_TM = (
			SELECT MAX(ELH.TRANSACTION_DT_TM)
			FROM ENCNTR_LOC_HIST ELH
			WHERE
				ORD_ACTIONS.ENCNTR_ID = ELH.ENCNTR_ID
				AND ELH.TRANSACTION_DT_TM <= ORD_ACTIONS.ACTION_DT_TM
		)
		AND ENCNTR_LOC_HIST.END_EFFECTIVE_DT_TM >= ORD_ACTIONS.ACTION_DT_TM
)

SELECT DISTINCT
	pi_from_gmt(TRUNC(REVIEWS.REVIEW_DT_TM, 'HH'), (pi_time_zone(1, @Variable('BOUSER')))) AS REVIEW_HOUR,
	pi_from_gmt(REVIEWS.ACTION_DT_TM, (pi_time_zone(1, @Variable('BOUSER')))) AS ORDER_DATETIME,
	pi_from_gmt(REVIEWS.REVIEW_DT_TM, (pi_time_zone(1, @Variable('BOUSER')))) AS REVIEW_DATETIME,
	(REVIEWS.REVIEW_DT_TM - REVIEWS.ACTION_DT_TM) * 24 * 60 AS ORDER_REVIEW_MIN,
	REVIEWS.NAME_FULL_FORMATTED AS PHARMACIST,
	pi_get_cv_display(REVIEWS.CATALOG_CD) AS MEDICATION,
	pi_get_cv_display(REVIEWS.ACTION_TYPE_CD) AS ACTION_TYPE,
	pi_get_cv_display(REVIEWS.LOC_NURSE_UNIT_CD) AS NURSE_UNIT,
	REVIEWS.ORDER_ID,
	CASE REVIEWS.REVIEWED_STATUS_FLAG
		WHEN 1 THEN 'Accepted'
		WHEN 2 THEN 'Rejected'
		WHEN 5 THEN 'Reviewed'
	END AS VERIFIED_STATUS
FROM
	REVIEWS
WHERE
	REVIEWS.REVIEW_DT_TM BETWEEN
/*
		pi_to_gmt(TRUNC(SYSDATE) - 1, pi_time_zone(2, @Variable('BOUSER')))
		AND pi_to_gmt(TRUNC(SYSDATE) - (1 / 86400), pi_time_zone(2, @Variable('BOUSER')))
*/
		DECODE(
			@Prompt('Choose date range', 'A', {'Yesterday', 'User-defined'}, mono, free, , , User:79),
			'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - 1, pi_time_zone(2, @Variable('BOUSER'))),
			'User-defined', pi_to_gmt(
				TO_DATE(
					@Prompt('Enter begin date (Leave as 01/01/1800 if using a Relative Date)', 'D', , mono, free, persistent, {'01/01/1800 00:00:00'}, User:80),
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				),
				pi_time_zone(1, @Variable('BOUSER')))
		)
		AND DECODE(
			@Prompt('Choose date range', 'A', {'Yesterday', 'User-defined'}, mono, free, , , User:79),
			'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - (1 / 86400), pi_time_zone(2, @Variable('BOUSER'))),
			'User-defined', pi_to_gmt(
				TO_DATE(
					@Prompt('Enter end date (Leave as 01/01/1800 if using a Relative Date)', 'D', , mono, free, persistent, {'01/01/1800 23:59:59'}, User:81),
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				),
				pi_time_zone(1, @Variable('BOUSER')))
		)
		
-- //mh.org/public/HER/HER - Pharmacy/Order Actions Report
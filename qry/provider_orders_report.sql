WITH PROVIDER_ORDERS AS (
	SELECT DISTINCT
		ORDER_ACTION.ORDER_ACTION_ID,
		PRSNL.NAME_FULL_FORMATTED,
		ORDER_ACTION.ACTION_TYPE_CD,
		ORDER_ACTION.COMMUNICATION_TYPE_CD
	FROM
		ENCNTR_LOC_HIST,
		ORDER_ACTION,
		ORDERS,
		PRSNL
	WHERE
		ORDER_ACTION.ACTION_DT_TM BETWEEN
			DECODE(
				@Prompt('Choose date range', 'A', {'Last Month', 'User-defined'}, mono, free, , , User:0),
				'Last Month', pi_to_gmt(TRUNC(ADD_MONTHS(SYSDATE, -1), 'MONTH'), pi_time_zone(2, @Variable('BOUSER'))),
				'User-defined', pi_to_gmt(
					TO_DATE(
						@Prompt('Enter begin date', 'D', , mono, free, persistent, {'01/01/1800 00:00:00'}, User:1),
						pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
					),
					pi_time_zone(1, @Variable('BOUSER')))
			)
			AND DECODE(
				@Prompt('Choose date range', 'A', {'Last Month', 'User-defined'}, mono, free, , , User:0),
				'Last Month', pi_to_gmt(TRUNC(SYSDATE, 'MONTH') - 1/86400, pi_time_zone(2, @Variable('BOUSER'))),
				'User-defined', pi_to_gmt(
					TO_DATE(
						@Prompt('Enter end date', 'D', , mono, free, persistent, {'01/01/1800 23:59:59'}, User:2),
						pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
					),
					pi_time_zone(1, @Variable('BOUSER')))
			)
		AND ORDER_ACTION.ORDER_ID = ORDERS.ORDER_ID
		AND (
			ORDER_ACTION.ACTION_PERSONNEL_ID IN @Prompt('Provider Id', 'N', , multi, free, persistent,, User:3)
			OR (
				ORDER_ACTION.ORDER_PROVIDER_ID IN @Prompt('Provider Id', 'N', , multi, free, persistent,, User:3)
				AND ORDER_ACTION.COMMUNICATION_TYPE_CD = 95480246 -- eVerbal - Read Back
			)
		)
		AND ORDERS.ACTIVITY_TYPE_CD = 378 -- Pharmacy
		AND ORDERS.CATALOG_TYPE_CD = 1363 -- Pharmacy
		AND ORDERS.TEMPLATE_ORDER_ID = 0
		AND ORDERS.ORIG_ORD_AS_FLAG IN (0, 1) -- Normal order
		AND ORDERS.ENCNTR_ID = ENCNTR_LOC_HIST.ENCNTR_ID
		AND ENCNTR_LOC_HIST.BEG_EFFECTIVE_DT_TM <= ORDER_ACTION.ACTION_DT_TM
		AND ENCNTR_LOC_HIST.TRANSACTION_DT_TM = (
			SELECT MAX(ELH.TRANSACTION_DT_TM)
			FROM ENCNTR_LOC_HIST ELH
			WHERE
				ORDERS.ENCNTR_ID = ELH.ENCNTR_ID
				AND ELH.TRANSACTION_DT_TM <= ORDER_ACTION.ACTION_DT_TM
		)
		AND ENCNTR_LOC_HIST.END_EFFECTIVE_DT_TM >= ORDER_ACTION.ACTION_DT_TM
		AND ENCNTR_LOC_HIST.LOC_FACILITY_CD IN (
			3310, -- HH HERMANN
			3796, -- HC Childrens
			3821, -- HH Clinics
			3822, -- HH Trans Care
			3823, -- HH Rehab
			1099966301 -- HH Oncology TMC
		)
		AND CASE
			WHEN ORDER_ACTION.ACTION_PERSONNEL_ID IN @Prompt('Provider Id', 'N', , multi, free, persistent,, User:3) THEN ORDER_ACTION.ACTION_PERSONNEL_ID
			WHEN ORDER_ACTION.ORDER_PROVIDER_ID IN @Prompt('Provider Id', 'N', , multi, free, persistent,, User:3) THEN ORDER_ACTION.ORDER_PROVIDER_ID
		END = PRSNL.PERSON_ID
)

SELECT
	NAME_FULL_FORMATTED AS PROVIDER,
	pi_get_cv_display(ACTION_TYPE_CD) AS ACTION_TYPE,
	pi_get_cv_display(COMMUNICATION_TYPE_CD) AS COMM_TYPE,
	COUNT(DISTINCT ORDER_ACTION_ID) AS NUM_ORDERS
FROM
	PROVIDER_ORDERS
WHERE
	COMMUNICATION_TYPE_CD <> 0
GROUP BY
	ACTION_TYPE_CD,
	COMMUNICATION_TYPE_CD,
	NAME_FULL_FORMATTED

-- 94498610;86816843;88770286;99677985;91826257;105539624;94473592;83246004;81302891;99629924;106715334;105652803
-- 94498610;106610654;95832907;105538927;101180233;99650870;99702981;82838813;99628546;105652803;99538538
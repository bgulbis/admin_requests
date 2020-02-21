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
		-- ORDER_ACTION.ACTION_DT_TM BETWEEN
		ORDERS.ORIG_ORDER_DT_TM BETWEEN
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
				@Prompt('Choose date range', 'A', {'Last Month', 'User-defined'}, mono, free, , , User:79),
				'Last Month', pi_to_gmt(TRUNC(SYSDATE, 'MONTH') - 1/86400, pi_time_zone(2, @Variable('BOUSER'))),
				'User-defined', pi_to_gmt(
					TO_DATE(
						@Prompt('Enter end date', 'D', , mono, free, persistent, {'01/01/1800 23:59:59'}, User:2),
						pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
					),
					pi_time_zone(1, @Variable('BOUSER')))
			)
		-- AND ORDERS.CATALOG_TYPE_CD = 1363 -- Pharmacy
		AND ORDERS.ACTIVITY_TYPE_CD = 378 -- Pharmacy
		AND ORDERS.ORDER_ID = ORDER_ACTION.ORDER_ID
		AND ORDER_ACTION.ACTION_SEQUENCE = 1
		-- AND ORDER_ACTION.ACTION_TYPE_CD = 1376 -- Order
)

SELECT * FROM ORD_ACTIONS
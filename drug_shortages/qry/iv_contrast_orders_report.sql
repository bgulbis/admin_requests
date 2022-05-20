WITH DYE_ORDERS AS (
	SELECT DISTINCT
		ORDERS.ENCNTR_ID,
		pi_from_gmt(ORDERS.ORIG_ORDER_DT_TM, 'America/Chicago') AS ORDER_DATETIME,
		ORDERS.ORDER_ID,
		pi_get_cv_display(ORDERS.CATALOG_CD) AS MEDICATION,
		pi_get_cv_display(ORDERS.CONTRIBUTOR_SYSTEM_CD) AS CONTRIB_SYS
	FROM
		ENCOUNTER,
		ORDERS
	WHERE
		ENCOUNTER.ORGANIZATION_ID = 1 -- Memorial Hermann Hospital
		AND ENCOUNTER.PERSON_ID = ORDERS.PERSON_ID
		AND ENCOUNTER.ENCNTR_ID = ORDERS.ENCNTR_ID
		AND ORDERS.CATALOG_CD IN (
			9907439, -- iohexol
			9912006 -- iodixanol
		) 
		AND ORDERS.ORIG_ORDER_DT_TM BETWEEN
			DECODE(
				@Prompt('Choose date range', 'A', {'Last Week', 'Last Month', 'User-defined'}, mono, free, , , User:0),
				'Last Week', pi_to_gmt(TRUNC(SYSDATE - 7, 'DAY'), 'America/Chicago'),
				'Last Month', pi_to_gmt(TRUNC(ADD_MONTHS(SYSDATE, -1), 'MONTH'), 'America/Chicago'),
				'User-defined', pi_to_gmt(
					TO_DATE(
						@Prompt('Enter begin date', 'D', , mono, free, persistent, {'05/01/2021 00:00:00'}, User:1),
						pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
					),
					pi_time_zone(1, 'America/Chicago')
				)
			)
			AND DECODE(
				@Prompt('Choose date range', 'A', {'Last Week', 'Last Month', 'User-defined'}, mono, free, , , User:0),
				'Last Week', pi_to_gmt(TRUNC(SYSDATE, 'DAY') - (1 / 86400), 'America/Chicago'),
				'Last Month', pi_to_gmt(TRUNC(SYSDATE, 'MONTH') - 1/86400, 'America/Chicago'),
				'User-defined', pi_to_gmt(
					TO_DATE(
						@Prompt('Enter end date', 'D', , mono, free, persistent, {'05/01/2022 00:00:00'}, User:2),
						pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
					) - 1/86400,
					pi_time_zone(1, 'America/Chicago')
				)
			)
)

SELECT DISTINCT
	DYE_ORDERS.*,
	ORDER_PRODUCT.ITEM_ID,
	ORDER_PRODUCT.DOSE_QUANTITY,
	pi_get_cv_display(ORDER_PRODUCT.DOSE_QUANTITY_UNIT_CD) AS DOSE_QUANTITY_UNIT,
	MED_IDENTIFIER.VALUE AS PRODUCT
	-- CHARGE.CHARGE_TYPE_CD,
	-- pi_get_cv_display(CHARGE.CHARGE_TYPE_CD) AS CHARGE_TYPE,
	-- CHARGE.ITEM_QUANTITY
FROM
	-- CHARGE,
	DYE_ORDERS,
	MED_IDENTIFIER,
	ORDER_PRODUCT
WHERE
	DYE_ORDERS.ORDER_ID = ORDER_PRODUCT.ORDER_ID
	AND ORDER_PRODUCT.ACTION_SEQUENCE = 1
	AND ORDER_PRODUCT.INGRED_SEQUENCE = 1
	AND ORDER_PRODUCT.ITEM_ID = MED_IDENTIFIER.ITEM_ID
	AND MED_IDENTIFIER.MED_IDENTIFIER_TYPE_CD = 1564 -- Generic Name
	AND MED_IDENTIFIER.MED_PRODUCT_ID = 0
	-- AND DYE_ORDERS.ORDER_ID = CHARGE.ORDER_ID
	-- AND CHARGE.CHARGE_TYPE_CD IN (
		-- 1871, -- CREDIT
		-- 1872 -- DEBIT
	-- )
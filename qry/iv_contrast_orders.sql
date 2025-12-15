WITH DOSES AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.PERSON_ID
/* 		CLINICAL_EVENT.EVENT_END_DT_TM,
		pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, 'America/Chicago') AS DOSE_DATETIME,
		TRUNC(pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, 'America/Chicago'), 'MONTH') AS DOSE_MONTH,
		CLINICAL_EVENT.EVENT_ID,
		CLINICAL_EVENT.ORDER_ID,
		CASE 
			WHEN ORDERS.TEMPLATE_ORDER_ID = 0 THEN ORDERS.ORDER_ID
			ELSE ORDERS.TEMPLATE_ORDER_ID
		END AS ORIG_ORDER_ID,
		-- CLINICAL_EVENT.EVENT_CD,
		CE_MED_RESULT.ADMIN_DOSAGE,
		pi_get_cv_display(CE_MED_RESULT.DOSAGE_UNIT_CD) AS DOSE_UNITS,
		CE_MED_RESULT.INFUSION_RATE,
		pi_get_cv_display(CE_MED_RESULT.INFUSION_UNIT_CD) AS RATE_UNITS,
		pi_get_cv_display(CE_MED_RESULT.IV_EVENT_CD) AS IV_EVENT,
		LOWER(pi_get_cv_display(CLINICAL_EVENT.EVENT_CD)) AS MEDICATION,
		pi_get_cv_display(ENCNTR_LOC_HIST.LOC_FACILITY_CD) AS FACILITY,
		pi_get_cv_display(ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD) AS NURSE_UNIT,
		pi_get_cv_display(ENCNTR_LOC_HIST.MED_SERVICE_CD) AS MED_SERVICE */
	FROM
		CE_MED_RESULT,
		CLINICAL_EVENT,
		ENCNTR_LOC_HIST
		-- ORDERS
	WHERE
		CLINICAL_EVENT.EVENT_CD IN (
			37557316, -- iodixanol
			37557318 -- iohexol
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM BETWEEN
			DECODE(
				@Prompt('Choose date range', 'A', {'Last Month', 'User-defined'}, mono, free, , , User:0),
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
				@Prompt('Choose date range', 'A', {'Last Month', 'User-defined'}, mono, free, , , User:0),
				'Last Month', pi_to_gmt(TRUNC(SYSDATE, 'MONTH') - 1/86400, 'America/Chicago'),
				'User-defined', pi_to_gmt(
					TO_DATE(
						@Prompt('Enter end date', 'D', , mono, free, persistent, {'05/01/2022 00:00:00'}, User:2),
						pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
					) - 1/86400,
					pi_time_zone(1, 'America/Chicago')
				)
			)
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND CLINICAL_EVENT.EVENT_ID = CE_MED_RESULT.EVENT_ID
		AND CE_MED_RESULT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
/* 		AND (
			(CE_MED_RESULT.ADMIN_DOSAGE > 0 AND CE_MED_RESULT.IV_EVENT_CD = 0)
			OR CE_MED_RESULT.IV_EVENT_CD = 688706 -- Begin Bag
		) */
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
		AND ENCNTR_LOC_HIST.LOC_FACILITY_CD IN (
			3310, -- HH HERMANN
			3796, -- HC Childrens
			3821, -- HH Clinics
			3822, -- HH Trans Care
			3823, -- HH Rehab
			1099966301 -- HH Oncology TMC
		)
		AND ENCNTR_LOC_HIST.END_EFFECTIVE_DT_TM >= CLINICAL_EVENT.EVENT_END_DT_TM
		AND ENCNTR_LOC_HIST.ACTIVE_IND = 1
		-- AND CLINICAL_EVENT.ORDER_ID = ORDERS.ORDER_ID
)

SELECT DISTINCT
	ORDERS.ENCNTR_ID,
	pi_from_gmt(ORDERS.ORIG_ORDER_DT_TM, 'America/Chicago') AS ORDER_DATETIME,
	ORDERS.ORDER_ID,
	pi_get_cv_display(ORDERS.CATALOG_CD) AS MEDICATION,
	pi_get_cv_display(ORDERS.CONTRIBUTOR_SYSTEM_CD) AS CONTRIB_SYS,
	ORDER_PRODUCT.ITEM_ID,
	ORDER_PRODUCT.DOSE_QUANTITY,
	pi_get_cv_display(ORDER_PRODUCT.DOSE_QUANTITY_UNIT_CD) AS DOSE_QUANTITY_UNIT,
	MED_IDENTIFIER.VALUE AS PRODUCT,
	-- CHARGE.BILL_ITEM_ID,
	pi_get_cv_display(CHARGE.CHARGE_TYPE_CD) AS CHARGE_TYPE,
	CHARGE.ITEM_QUANTITY
FROM
	CHARGE,
	DOSES,
	ENCNTR_LOC_HIST,
	MED_IDENTIFIER,
	ORDER_PRODUCT,
	ORDERS
WHERE
	DOSES.ENCNTR_ID = ORDERS.ENCNTR_ID
	AND ORDERS.CATALOG_CD IN (
		9907439, -- iohexol
		9912006 -- iodixanol
	)
	AND ORDERS.ORIG_ORDER_DT_TM BETWEEN
		DECODE(
			@Prompt('Choose date range', 'A', {'Last Month', 'User-defined'}, mono, free, , , User:0),
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
			@Prompt('Choose date range', 'A', {'Last Month', 'User-defined'}, mono, free, , , User:0),
			'Last Month', pi_to_gmt(TRUNC(SYSDATE, 'MONTH') - 1/86400, 'America/Chicago'),
			'User-defined', pi_to_gmt(
				TO_DATE(
					@Prompt('Enter end date', 'D', , mono, free, persistent, {'05/01/2022 00:00:00'}, User:2),
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				) - 1/86400,
				pi_time_zone(1, 'America/Chicago')
			)
		)
	AND ORDERS.ENCNTR_ID = ENCNTR_LOC_HIST.ENCNTR_ID
	AND ENCNTR_LOC_HIST.BEG_EFFECTIVE_DT_TM <= ORDERS.ORIG_ORDER_DT_TM
	AND ENCNTR_LOC_HIST.TRANSACTION_DT_TM = (
		SELECT MAX(ELH.TRANSACTION_DT_TM)
		FROM ENCNTR_LOC_HIST ELH
		WHERE
			ORDERS.ENCNTR_ID = ELH.ENCNTR_ID
			AND ELH.TRANSACTION_DT_TM <= ORDERS.ORIG_ORDER_DT_TM
			AND ELH.ACTIVE_IND = 1
	)
	AND ENCNTR_LOC_HIST.LOC_FACILITY_CD IN (
		3310, -- HH HERMANN
		3796, -- HC Childrens
		3821, -- HH Clinics
		3822, -- HH Trans Care
		3823, -- HH Rehab
		1099966301 -- HH Oncology TMC
	)
	AND ENCNTR_LOC_HIST.END_EFFECTIVE_DT_TM >= ORDERS.ORIG_ORDER_DT_TM
	AND ENCNTR_LOC_HIST.ACTIVE_IND = 1
	AND ORDERS.ORDER_ID = ORDER_PRODUCT.ORDER_ID(+)
	AND ORDER_PRODUCT.INGRED_SEQUENCE(+) = 1
	AND ORDER_PRODUCT.ITEM_ID = MED_IDENTIFIER.ITEM_ID(+)
	AND MED_IDENTIFIER.MED_IDENTIFIER_TYPE_CD(+) = 1564 -- Generic Name
	AND MED_IDENTIFIER.MED_PRODUCT_ID(+) = 0
	AND ORDERS.ORDER_ID = CHARGE.ORDER_ID(+)
	-- AND CHARGE.CHARGE_TYPE_CD(+) = 1872 -- DEBIT

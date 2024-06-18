WITH DOSES AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CASE
			WHEN ORDERS.TEMPLATE_ORDER_ID = 0 THEN ORDERS.ORDER_ID
			ELSE ORDERS.TEMPLATE_ORDER_ID
		END AS ORIG_ORDER_ID,
		ENCOUNTER.REASON_FOR_VISIT AS ADMIT_REASON
		-- pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, 'America/Chicago') AS MED_DATETIME,
		-- CLINICAL_EVENT.EVENT_ID,
		-- pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS MEDICATION,
		-- CE_MED_RESULT.ADMIN_DOSAGE AS DOSE,
		-- pi_get_cv_display(CE_MED_RESULT.DOSAGE_UNIT_CD) AS DOSE_UNIT,
		-- CE_MED_RESULT.INFUSION_RATE AS RATE,
		-- pi_get_cv_display(CE_MED_RESULT.INFUSION_UNIT_CD) AS RATE_UNIT,
		-- pi_get_cv_display(CE_MED_RESULT.ADMIN_ROUTE_CD) AS ROUTE,
		-- pi_get_cv_display(CE_MED_RESULT.IV_EVENT_CD) AS IV_EVENT,
		-- pi_get_cv_display(ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD) AS NURSE_UNIT,
		-- CASE WHEN ORDERS.PRN_IND = 1 THEN 'PRN' END AS PRN_DOSE
	FROM 
		CE_MED_RESULT,
		CLINICAL_EVENT,
		ENCNTR_LOC_HIST,
		ENCOUNTER,
		ORDERS
	WHERE
		CLINICAL_EVENT.EVENT_CD = 37557146 -- heparin
		AND CLINICAL_EVENT.EVENT_END_DT_TM BETWEEN
			DECODE(
				@Prompt('Choose date range', 'A', {'Yesterday', 'Last Month', 'User-defined'}, mono, free, , , User:79),
				'Yesterday', pi_to_gmt(TRUNC(SYSDATE - 1), 'America/Chicago'),
				'Last Month', pi_to_gmt(TRUNC(ADD_MONTHS(SYSDATE, -1), 'MONTH'), 'America/Chicago'),
				'User-defined', pi_to_gmt(
					TO_DATE(
						@Prompt('Enter begin date', 'D', , mono, free, persistent, {'07/01/2021 00:00:00'}, User:80),
						pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
					),
					'America/Chicago'
				)
			)
			AND DECODE(
				@Prompt('Choose date range', 'A', {'Yesterday', 'Last Month', 'User-defined'}, mono, free, , , User:79),
				'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - 1/86400, 'America/Chicago'),
				'Last Month', pi_to_gmt(TRUNC(SYSDATE, 'MONTH') - 1/86400, 'America/Chicago'),
				'User-defined', pi_to_gmt(
					TO_DATE(
						@Prompt('Enter end date', 'D', , mono, free, persistent, {'11/01/2021 00:00:00'}, User:81),
						pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
					) - 1/86400,
					'America/Chicago'
				)
			)
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND CLINICAL_EVENT.EVENT_ID = CE_MED_RESULT.EVENT_ID
		AND CE_MED_RESULT.IV_EVENT_CD > 0
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
		AND ENCNTR_LOC_HIST.END_EFFECTIVE_DT_TM >= CLINICAL_EVENT.EVENT_END_DT_TM
		AND ENCNTR_LOC_HIST.ACTIVE_IND = 1   
		AND ENCNTR_LOC_HIST.LOC_FACILITY_CD IN (
			3310, -- HH HERMANN
			3796, -- HC Childrens
			3821, -- HH Clinics
			3822, -- HH Trans Care
			3823 -- HH Rehab		
		)
		AND CLINICAL_EVENT.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
		AND CLINICAL_EVENT.ORDER_ID = ORDERS.ORDER_ID
)

SELECT DISTINCT
	ENCNTR_ALIAS.ALIAS AS FIN,
	DOSES.*,
	pi_from_gmt(ORDERS.ORIG_ORDER_DT_TM, 'America/Chicago') AS ORDER_DATETIME,
	pi_get_cv_display(ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD) AS NURSE_UNIT,
	pi_get_cv_display(ENCNTR_LOC_HIST.MED_SERVICE_CD) AS MED_SERVICE,
	PATHWAY_CATALOG.DESCRIPTION AS ORDER_FROM_MPP
	-- MAX(ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE) KEEP (DENSE_RANK LAST ORDER BY ORDER_DETAIL.ACTION_SEQUENCE) OVER (PARTITION BY ORDER_DETAIL.ORDER_ID) AS ORDER_WEIGHT
	-- PATHWAY_CATALOG.PATHWAY_CATALOG_ID
FROM
	DOSES,
	ENCNTR_ALIAS,
	ENCNTR_LOC_HIST,
	-- ORDER_DETAIL,
	ORDERS,
	PATHWAY_CATALOG
WHERE
	DOSES.ORIG_ORDER_ID = ORDERS.ORDER_ID
	AND ORDERS.ORIG_ORDER_DT_TM BETWEEN
		DECODE(
			@Prompt('Choose date range', 'A', {'Yesterday', 'Last Month', 'User-defined'}, mono, free, , , User:79),
			'Yesterday', pi_to_gmt(TRUNC(SYSDATE - 1), 'America/Chicago'),
			'Last Month', pi_to_gmt(TRUNC(ADD_MONTHS(SYSDATE, -1), 'MONTH'), 'America/Chicago'),
			'User-defined', pi_to_gmt(
				TO_DATE(
					@Prompt('Enter begin date', 'D', , mono, free, persistent, {'07/01/2021 00:00:00'}, User:80),
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				),
				'America/Chicago'
			)
		)
		AND DECODE(
			@Prompt('Choose date range', 'A', {'Yesterday', 'Last Month', 'User-defined'}, mono, free, , , User:79),
			'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - 1/86400, 'America/Chicago'),
			'Last Month', pi_to_gmt(TRUNC(SYSDATE, 'MONTH') - 1/86400, 'America/Chicago'),
			'User-defined', pi_to_gmt(
				TO_DATE(
					@Prompt('Enter end date', 'D', , mono, free, persistent, {'11/01/2021 00:00:00'}, User:81),
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				) - 1/86400,
				'America/Chicago'
			)
		)
	AND ORDERS.PATHWAY_CATALOG_ID = PATHWAY_CATALOG.PATHWAY_CATALOG_ID
	-- AND PATHWAY_CATALOG.PATHWAY_CATALOG_ID IN (
		-- 482124823, -- Heparin Weight Based Orders Deep Vein Thrombosis Pulmonary Embolism MPP
		-- 537945024, -- Heparin Weight Based Orders for Acute Coronary Syndromes MPP
		-- 537946887 -- Heparin Weight Based Atrial Fibrillation and Stroke Prevention Orders MPP
	-- )
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
	AND ENCNTR_LOC_HIST.END_EFFECTIVE_DT_TM >= ORDERS.ORIG_ORDER_DT_TM
	AND ENCNTR_LOC_HIST.ACTIVE_IND = 1
	-- AND ORDERS.ORDER_ID = ORDER_DETAIL.ORDER_ID(+)
	-- AND ORDER_DETAIL.OE_FIELD_MEANING_ID(+) = 99 -- WEIGHT
	-- AND ORDER_DETAIL.ACTION_SEQUENCE(+) = 1
	AND DOSES.ENCNTR_ID = ENCNTR_ALIAS.ENCNTR_ID
	AND ENCNTR_ALIAS.ENCNTR_ALIAS_TYPE_CD = 619 -- FIN NBR
	AND ENCNTR_ALIAS.ACTIVE_IND = 1
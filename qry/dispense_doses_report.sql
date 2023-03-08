WITH PATIENTS AS (
	SELECT DISTINCT
		ENCOUNTER.ENCNTR_ID,
		ENCOUNTER.PERSON_ID,
		pi_from_gmt(ENCOUNTER.REG_DT_TM, 'America/Chicago') AS ADMIT_DATETIME,
		pi_from_gmt(ENCOUNTER.DISCH_DT_TM, 'America/Chicago') AS DISCH_DATETIME,
		pi_get_cv_display(ENCOUNTER.LOC_FACILITY_CD) AS FACILITY,
		pi_get_cv_display(ENCOUNTER.ENCNTR_TYPE_CLASS_CD) AS ENCNTR_TYPE
	FROM
		ENCOUNTER
	WHERE
		ENCOUNTER.ORGANIZATION_ID = 1 -- Memorial Hermann Hospital
		AND (
			ENCOUNTER.DISCH_DT_TM >=
				DECODE(
					@Prompt('Choose date range', 'A', {'Yesterday', 'User-defined'}, mono, free, , , User:0),
					'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - 1, 'America/Chicago'),
					'User-defined', pi_to_gmt(
						TO_DATE(
							@Prompt('Enter begin date', 'D', , mono, free, persistent, {'12/01/2022 00:00:00'}, User:1),
							pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
						),
						pi_time_zone(1, 'America/Chicago')
					)
				)
			OR ENCOUNTER.DISCH_DT_TM IS NULL
		)
		AND ENCOUNTER.REG_DT_TM > DATE '2020-01-01'
		AND ENCOUNTER.REG_DT_TM <=
			DECODE(
				@Prompt('Choose date range', 'A', {'Yesterday', 'User-defined'}, mono, free, , , User:0),
				'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - 1/86400, 'America/Chicago'),
				'User-defined', pi_to_gmt(
					TO_DATE(
						@Prompt('Enter end date', 'D', , mono, free, persistent, {'03/01/2023 00:00:00'}, User:2),
						pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
					) - 1/86400,
					pi_time_zone(1, 'America/Chicago')
				)
			)
		AND ENCOUNTER.LOC_FACILITY_CD IN (
			3310, -- HH HERMANN
			3796, -- HC Childrens
			3821, -- HH Clinics
			3822, -- HH Trans Care
			3823, -- HH Rehab
			1099966301 -- HH Oncology TMC	
		)		
		AND ENCOUNTER.ACTIVE_IND = 1
		AND ENCOUNTER.ENCNTR_TYPE_CLASS_CD <> 42634 -- Preadmit
), PHARM_ORDERS AS (
	SELECT DISTINCT
		ORDERS.ENCNTR_ID,
		ORDERS.ORDER_ID,
		ORDERS.TEMPLATE_ORDER_ID,
		pi_from_gmt(ORDERS.ORIG_ORDER_DT_TM, 'America/Chicago') AS ORDER_DATETIME,
		pi_get_cv_display(ENCNTR_LOC_HIST.LOC_FACILITY_CD) AS FACILITY,
		pi_get_cv_display(ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD) AS NURSE_UNIT,
		-- ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE AS DISPENSE_FROM,
		DISPENSE_HX.DISPENSE_HX_ID,
		DISPENSE_HX.DISPENSE_DT_TM,
		pi_from_gmt(DISPENSE_HX.DISPENSE_DT_TM, 'America/Chicago') AS DISPENSE_DATETIME,
		TRUNC(pi_from_gmt(DISPENSE_HX.DISPENSE_DT_TM, 'America/Chicago'), 'MONTH') AS DISPENSE_MONTH,
		pi_get_cv_display(DISPENSE_HX.DISP_EVENT_TYPE_CD) AS DISP_EVENT_TYPE,
		pi_get_cv_display(DISPENSE_HX.DISP_SR_CD) AS DISP_FROM
/* 		CASE
			WHEN pi_get_cv_display(DISP_EVENT_TYPE_CD) IN ('Device Return', 'Manual Credit') THEN DISPENSE_HX.DOSES * DISPENSE_HX.CHARGE_IND * -1
			ELSE DISPENSE_HX.DOSES * DISPENSE_HX.CHARGE_IND
		END AS DISP_AMT */
	FROM
		DISPENSE_HX,
		ENCNTR_LOC_HIST,
		-- ORDER_DETAIL,
		ORDERS,
		PATIENTS
	WHERE
		PATIENTS.ENCNTR_ID = ORDERS.ENCNTR_ID
		AND PATIENTS.PERSON_ID = ORDERS.PERSON_ID
		AND ORDERS.ACTIVITY_TYPE_CD = 378 -- Pharmacy
		AND ORDERS.CATALOG_TYPE_CD = 1363 -- Pharmacy
		-- AND ORDERS.ORDER_ID = ORDER_DETAIL.ORDER_ID(+)
		-- AND ORDER_DETAIL.ACTION_SEQUENCE = 1
		-- AND ORDER_DETAIL.OE_FIELD_MEANING_ID(+) = 2006 -- DISPENSEFROMLOC
		AND ORDERS.ORDER_ID = DISPENSE_HX.ORDER_ID
		AND ORDERS.ENCNTR_ID = ENCNTR_LOC_HIST.ENCNTR_ID
		AND ENCNTR_LOC_HIST.BEG_EFFECTIVE_DT_TM <= ORDERS.ORIG_ORDER_DT_TM
		AND ENCNTR_LOC_HIST.TRANSACTION_DT_TM = (
			SELECT MAX(ELH.TRANSACTION_DT_TM)
			FROM ENCNTR_LOC_HIST ELH
			WHERE
				ORDERS.ENCNTR_ID = ELH.ENCNTR_ID
				AND ELH.TRANSACTION_DT_TM <= ORDERS.ORIG_ORDER_DT_TM
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
)

SELECT 
	FACILITY,
	DISPENSE_MONTH,
	DISP_EVENT_TYPE,
	-- DISP_FROM,
	COUNT(DISTINCT DISPENSE_HX_ID) AS NUM_DISPENSED
FROM 
	PHARM_ORDERS
WHERE 
	REGEXP_INSTR(PHARM_ORDERS.NURSE_UNIT, '^CY') = 0
	AND PHARM_ORDERS.DISP_EVENT_TYPE NOT IN ('Device Return', 'Manual Credit')
	AND PHARM_ORDERS.DISPENSE_DT_TM BETWEEN 
		DECODE(
			@Prompt('Choose date range', 'A', {'Yesterday', 'User-defined'}, mono, free, , , User:0),
			'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - 1, 'America/Chicago'),
			'User-defined', pi_to_gmt(
				TO_DATE(
					@Prompt('Enter begin date', 'D', , mono, free, persistent, {'12/01/2022 00:00:00'}, User:1),
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				),
				pi_time_zone(1, 'America/Chicago')
			)
		)
		AND DECODE(
			@Prompt('Choose date range', 'A', {'Yesterday', 'User-defined'}, mono, free, , , User:0),
			'Yesterday', pi_to_gmt(TRUNC(SYSDATE) - 1/86400, 'America/Chicago'),
			'User-defined', pi_to_gmt(
				TO_DATE(
					@Prompt('Enter end date', 'D', , mono, free, persistent, {'03/01/2023 00:00:00'}, User:2),
					pi_get_dm_info_char_gen('Date Format Mask|FT','PI EXP|Systems Configuration|Date Format Mask')
				) - 1/86400,
				pi_time_zone(1, 'America/Chicago')
			)
		)
GROUP BY
	FACILITY,
	DISPENSE_MONTH,
	DISP_EVENT_TYPE
	-- DISP_FROM
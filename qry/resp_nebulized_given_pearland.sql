WITH DOSES AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CLINICAL_EVENT.PERSON_ID,
		CASE
			WHEN ORDERS.TEMPLATE_ORDER_ID = 0 THEN ORDERS.ORDER_ID
			ELSE ORDERS.TEMPLATE_ORDER_ID
		END AS ORIG_ORDER_ID,
		pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, 'America/Chicago') AS MED_DATETIME,
		TRUNC(pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, 'America/Chicago'), 'MONTH') AS MED_MONTH,
		TRUNC(ADD_MONTHS(pi_from_gmt(CLINICAL_EVENT.EVENT_END_DT_TM, 'America/Chicago'), 6), 'YEAR') AS FISCAL_YEAR,
		CLINICAL_EVENT.EVENT_ID,
		pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS MEDICATION,
		pi_get_cv_display(MED_ADMIN_EVENT.EVENT_TYPE_CD) AS ADMIN_EVENT,
		pi_get_cv_display(CE_MED_RESULT.ADMIN_ROUTE_CD) AS ADMIN_ROUTE,
		pi_get_cv_display(ENCNTR_LOC_HIST.LOC_FACILITY_CD) AS FACILITY,
		pi_get_cv_display(ENCNTR_LOC_HIST.LOC_NURSE_UNIT_CD) AS NURSE_UNIT
	FROM
		CE_MED_RESULT,
		CLINICAL_EVENT,
		ENCNTR_LOC_HIST,
		MED_ADMIN_EVENT,
		ORDERS
	WHERE
		CLINICAL_EVENT.EVENT_CD IN (
			37556036, -- acetylcysteine
			37556053, -- albuterol
			37556055, -- albuterol-ipratropium
			37556091, -- amikacin
			37556099, -- aminocaproic acid
			37556129, -- amphotericin B
			37556131, -- amphotericin B lipid complex
			37556132, -- amphotericin B liposomal
			185632998, -- arformoterol
			37556226, -- azelastine nasal
			37556259, -- beclomethasone
			37556343, -- budesonide
			251901141, -- budesonide-formoterol
			51208916, -- ciprofloxacin-dexamethasone
			37556606, -- colistimethate
			37556638, -- cromolyn
			37556701, -- dexamethasone
			37556709, -- dexmedetomidine
			37556797, -- dornase alfa
			37556849, -- EPINephrine
			37556863, -- epoprostenol
			37557014, -- fluticasone
			37557015, -- fluticasone nasal
			37557020, -- fluticasone-salmeterol
			535736264, -- formoterol-mometasone
			37557069, -- gentamicin
			37557105, -- glycopyrrolate
			37557146, -- heparin
			37557325, -- ipratropium
			37557367, -- ketamine
			37557410, -- levalbuterol
			37557428, -- lidocaine
			48069083, -- lidocaine topical
			37557562, -- methylPREDNISolone
			117038871, -- mometasone
			37557749, -- oxymetazoline nasal
			37557788, -- pentamidine
			535736304, -- racepinephrine
			37558005, -- ropivacaine 0.2% INJ
			37558020, -- salmeterol
			37558395, -- Sodium Chloride 0.45% IV
			37558394, -- Sodium Chloride 0.9% IV
			37558392, -- Sodium Chloride 3% IV
			117039032, -- tiotropium
			37558218, -- tobramycin
			48069081, -- tranexamic acid
			1056676696, -- umeclidinium-vilanterol
			37558315 -- vancomycin
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
		AND CLINICAL_EVENT.EVENT_ID = CE_MED_RESULT.EVENT_ID(+)
		AND CE_MED_RESULT.VALID_UNTIL_DT_TM(+) > DATE '2099-12-31'
		AND CLINICAL_EVENT.EVENT_ID = MED_ADMIN_EVENT.EVENT_ID
		AND CLINICAL_EVENT.ORDER_ID = ORDERS.ORDER_ID	
		AND CLINICAL_EVENT.ENCNTR_ID = ENCNTR_LOC_HIST.ENCNTR_ID
		AND ENCNTR_LOC_HIST.BEG_EFFECTIVE_DT_TM <= CLINICAL_EVENT.EVENT_END_DT_TM
		AND ENCNTR_LOC_HIST.TRANSACTION_DT_TM = (
			SELECT MAX(ELH.TRANSACTION_DT_TM)
			FROM ENCNTR_LOC_HIST ELH
			WHERE
				CLINICAL_EVENT.ENCNTR_ID = ELH.ENCNTR_ID
				AND ELH.TRANSACTION_DT_TM <= CLINICAL_EVENT.EVENT_END_DT_TM
		)
		AND ENCNTR_LOC_HIST.LOC_FACILITY_CD = 1824255295 --- BL PEARLAND
		AND ENCNTR_LOC_HIST.END_EFFECTIVE_DT_TM >= CLINICAL_EVENT.EVENT_END_DT_TM
		AND ENCNTR_LOC_HIST.ACTIVE_IND = 1
), ORDER_ROUTE AS (
	SELECT
		DOSES.*,
		ORDER_DETAIL.OE_FIELD_DISPLAY_VALUE AS RXROUTE
	FROM
		DOSES,
		ORDER_DETAIL,
		ORDERS
	WHERE
		DOSES.ORIG_ORDER_ID = ORDERS.ORDER_ID
		AND ORDERS.ORDER_ID = ORDER_DETAIL.ORDER_ID
		AND ORDER_DETAIL.OE_FIELD_MEANING_ID = 2050 -- RXROUTE
		AND ORDER_DETAIL.ACTION_SEQUENCE = 1
)

SELECT
	FACILITY,
	FISCAL_YEAR,
	MED_MONTH,
	RXROUTE,
	ADMIN_EVENT,
	COUNT(DISTINCT EVENT_ID) AS NUM_EVENTS
FROM
	ORDER_ROUTE
WHERE
	RXROUTE = 'NEB'
	-- OR (
		-- RXROUTE = 'INHALER' 
		-- AND FACILITY = 'HC Childrens'
	-- )
GROUP BY
	FACILITY,
	FISCAL_YEAR,
	MED_MONTH,
	RXROUTE,
	ADMIN_EVENT
	
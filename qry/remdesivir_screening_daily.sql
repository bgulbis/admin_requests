WITH TMC_PTS AS (
	SELECT DISTINCT
		ENCNTR_DOMAIN.ENCNTR_ID,
		ENCNTR_DOMAIN.PERSON_ID,
		ENCOUNTER.DISCH_DT_TM
	FROM
		ENCNTR_DOMAIN,
		ENCOUNTER
	WHERE
		ENCNTR_DOMAIN.LOC_FACILITY_CD IN (
			3310, -- HH HERMANN
			-- 3796, -- HC Childrens
			-- 3821, -- HH Clinics
			3822, -- HH Trans Care
			3823 -- HH Rehab
		) 
		AND ENCNTR_DOMAIN.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
		AND ENCOUNTER.DISCH_DT_TM IS NULL
		AND ENCOUNTER.ENCNTR_TYPE_CLASS_CD IN (
			42631, -- Inpatient
			55851, -- Emergency
			688523 -- Observation
		)
), COVID_TEST AS (
	SELECT DISTINCT
		TMC_PTS.ENCNTR_ID,
		CLINICAL_EVENT.ENCNTR_ID AS CE_ENCNTR_ID,
		CLINICAL_EVENT.PERSON_ID,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		CLINICAL_EVENT.EVENT_ID,
		CLINICAL_EVENT.RESULT_VAL
	FROM
		CLINICAL_EVENT,
		TMC_PTS
	WHERE
/* 		TMC_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.ENCNTR_ID > 0
		AND EVENT_CLASS_CD = 162 -- TXT */
		TMC_PTS.ENCNTR_ID > 0
		AND TMC_PTS.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_CD = 3321641459 -- Coronavirus (COVID-19) NAA		
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 4, 'America/Chicago')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND CLINICAL_EVENT.RESULT_VAL = 'Detected'
), PREV_COVID AS (
	SELECT DISTINCT
		COVID_TEST.ENCNTR_ID,
		CLINICAL_EVENT.ENCNTR_ID AS CE_ENCNTR_ID,
		CLINICAL_EVENT.PERSON_ID,
		CLINICAL_EVENT.EVENT_END_DT_TM,
		CLINICAL_EVENT.EVENT_ID,
		CLINICAL_EVENT.RESULT_VAL
	FROM
		CLINICAL_EVENT,
		COVID_TEST
	WHERE
		COVID_TEST.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_CD = 3321641459 -- Coronavirus (COVID-19) NAA		
		AND CLINICAL_EVENT.EVENT_END_DT_TM BETWEEN
			pi_to_gmt(DATE '2020-01-01', 'America/Chicago')
			AND pi_to_gmt(SYSDATE - 4, 'America/Chicago')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND CLINICAL_EVENT.RESULT_VAL = 'Detected'
), COVID_PTS AS (
	SELECT *
	FROM 
		COVID_TEST
	WHERE
		COVID_TEST.PERSON_ID NOT IN (SELECT PERSON_ID FROM PREV_COVID)
), REMDES AS (
	SELECT DISTINCT
		COVID_PTS.ENCNTR_ID,
		CLINICAL_EVENT.ENCNTR_ID AS CE_ENCNTR_ID,
		CLINICAL_EVENT.PERSON_ID
	FROM
		CLINICAL_EVENT,
		COVID_PTS
	WHERE
		-- COVID_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		-- AND CLINICAL_EVENT.EVENT_CLASS_CD = 158 -- MED
		COVID_PTS.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_CD = 3406488593 -- remdesivir; item id: 301775257
		-- AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 14, 'America/Chicago')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
), REMDES_IDS AS (
	SELECT DISTINCT
		COVID_PTS.ENCNTR_ID,
		CLINICAL_EVENT.ENCNTR_ID AS CE_ENCNTR_ID,
		CLINICAL_EVENT.PERSON_ID
	FROM
		CLINICAL_EVENT,
		COVID_PTS,
		ORDER_PRODUCT,
		ORDERS
	WHERE
		-- COVID_PTS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		COVID_PTS.PERSON_ID = CLINICAL_EVENT.PERSON_ID
		AND CLINICAL_EVENT.EVENT_CD = 123988939 -- IDS med
		-- AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 14, 'America/Chicago')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
		AND CLINICAL_EVENT.ORDER_ID = ORDERS.ORDER_ID
		AND 
			CASE
				WHEN ORDERS.TEMPLATE_ORDER_ID = 0 THEN ORDERS.ORDER_ID
				ELSE ORDERS.TEMPLATE_ORDER_ID
			END = ORDER_PRODUCT.ORDER_ID
		AND ORDER_PRODUCT.INGRED_SEQUENCE =  1
		AND ORDER_PRODUCT.ITEM_ID = 301775257 -- remdesivir 100 mg/20 ml INJ VL
), REMDES_PTS AS (
	SELECT * FROM REMDES
	
	UNION
	
	SELECT * FROM REMDES_IDS
), LAST_POS AS (
	SELECT
		ENCNTR_ID,
		MAX(EVENT_END_DT_TM) AS EVENT_END_DT_TM
	FROM 
		COVID_PTS
	WHERE
		-- RESULT_VAL = 'Detected'
		PERSON_ID NOT IN (SELECT PERSON_ID FROM REMDES_PTS)
	GROUP BY
		ENCNTR_ID
), FIO2 AS (
	SELECT DISTINCT
		LAST_POS.ENCNTR_ID,
		MAX(CLINICAL_EVENT.EVENT_END_DT_TM) AS EVENT_END_DT_TM,
		MAX(CLINICAL_EVENT.RESULT_VAL) KEEP (DENSE_RANK LAST ORDER BY CLINICAL_EVENT.EVENT_END_DT_TM, CLINICAL_EVENT.EVENT_ID) AS FIO2
	FROM
		CLINICAL_EVENT,
		LAST_POS
	WHERE
		LAST_POS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CLINICAL_EVENT.EVENT_CD IN (
			10662250, -- FIO2 (%)
			515653299 -- POC A %FIO2
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 3, 'America/Chicago')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
	GROUP BY
		LAST_POS.ENCNTR_ID
), LABS AS (
	SELECT DISTINCT
		LAST_POS.ENCNTR_ID,
		pi_get_cv_display(CLINICAL_EVENT.EVENT_CD) AS EVENT,
		-- MAX(CLINICAL_EVENT.EVENT_END_DT_TM) AS EVENT_END_DT_TM,
		MAX(CLINICAL_EVENT.RESULT_VAL) KEEP (DENSE_RANK LAST ORDER BY CLINICAL_EVENT.EVENT_END_DT_TM, CLINICAL_EVENT.EVENT_ID) AS RESULT_VAL
	FROM
		CLINICAL_EVENT,
		LAST_POS
	WHERE
		LAST_POS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CLINICAL_EVENT.EVENT_CD IN (
			10739818, -- SpO2 percent
			10760974, -- O2 Flow Rate
			239993238, -- eGFR
			30349 -- ALT
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 3, 'America/Chicago')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'
	GROUP BY
		LAST_POS.ENCNTR_ID,
		CLINICAL_EVENT.EVENT_CD
), LABS_PIVOT AS (
	SELECT * FROM LABS
	PIVOT(
		MIN(RESULT_VAL) FOR EVENT IN (
			'SpO2 percent' AS SPO2_PCT,
			'O2 Flow Rate' AS O2_FLOW,
			'eGFR' AS EGFR,
			'ALT' AS ALT
		)
	)
), VENT_MODE AS (
	SELECT DISTINCT
		LAST_POS.ENCNTR_ID,
		MAX(CLINICAL_EVENT.EVENT_END_DT_TM) AS EVENT_END_DT_TM,
		MAX(CLINICAL_EVENT.RESULT_VAL) KEEP (DENSE_RANK LAST ORDER BY CLINICAL_EVENT.EVENT_END_DT_TM, CLINICAL_EVENT.EVENT_ID) AS RESP_MODE
	FROM
		CLINICAL_EVENT,
		LAST_POS
	WHERE
		LAST_POS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 162 -- TXT
		AND CLINICAL_EVENT.EVENT_CD IN (
			421788419, -- Non-Invasive Ventilation Mode
			421791215, -- Invasive Ventilation Mode
			421785649 -- Oxygen Therapy Mode
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 3, 'America/Chicago')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'	
	GROUP BY
		LAST_POS.ENCNTR_ID
), DIALYSIS AS (
	SELECT DISTINCT
		CLINICAL_EVENT.ENCNTR_ID,
		CASE MAX(CLINICAL_EVENT.EVENT_CD) KEEP (DENSE_RANK LAST ORDER BY CLINICAL_EVENT.EVENT_END_DT_TM, CLINICAL_EVENT.EVENT_ID)
			WHEN 333892069 THEN 'HD'
			WHEN 699896173 THEN 'HD'
			WHEN 333892112 THEN 'CRRT'
			WHEN 173565025 THEN 'CRRT'
			WHEN 333892090 THEN 'PD'
			WHEN 699896249 THEN 'PD'
		END AS DIALYSIS
	FROM
		CLINICAL_EVENT,
		LAST_POS
	WHERE
		LAST_POS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		--AND CLINICAL_EVENT.EVENT_CLASS_CD = 159 -- NUM
		AND CLINICAL_EVENT.EVENT_CD IN (
			333892069, -- Hemodialysis Output Vol
			333892090, -- Peritoneal Dialysis Output Vol
			333892112, -- CRRT Output Vol
			699896173, -- Hemodialysis Output Volume
			699896249, -- Peritoneal Dialysis Output Volume
			173565025 -- CRRT Actual Pt Fluid Removed Vol
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 3, 'America/Chicago')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'	
	GROUP BY
		CLINICAL_EVENT.ENCNTR_ID
), PRESSORS AS (
	SELECT DISTINCT
		LAST_POS.ENCNTR_ID,
		COUNT(DISTINCT CLINICAL_EVENT.EVENT_CD) AS NUM_PRESSORS
	FROM
		CE_MED_RESULT,
		CLINICAL_EVENT,
		LAST_POS
	WHERE
		LAST_POS.ENCNTR_ID = CLINICAL_EVENT.ENCNTR_ID
		AND CLINICAL_EVENT.EVENT_CLASS_CD = 158 -- MED
		AND CLINICAL_EVENT.EVENT_CD IN (
			37556849, -- EPINephrine
			37557691, -- norepinephrine
			37558389, -- DOPamine
			37557816, -- phenylephrine
			37558323 -- vasopressin
		)
		AND CLINICAL_EVENT.EVENT_END_DT_TM >= pi_to_gmt(SYSDATE - 1, 'America/Chicago')
		AND CLINICAL_EVENT.VALID_UNTIL_DT_TM > DATE '2099-12-31'	
		AND CLINICAL_EVENT.EVENT_ID = CE_MED_RESULT.EVENT_ID
		AND CE_MED_RESULT.VALID_UNTIL_DT_TM > DATE '2099-12-31'	
		AND CE_MED_RESULT.INFUSION_RATE > 0
	GROUP BY
		LAST_POS.ENCNTR_ID,
		CLINICAL_EVENT.EVENT_CD
)

SELECT
	pi_get_cv_display(ENCOUNTER.LOC_NURSE_UNIT_CD) AS NURSE_UNIT,
	pi_get_cv_display(ENCOUNTER.LOC_ROOM_CD) AS ROOM,
	pi_get_cv_display(ENCOUNTER.LOC_BED_CD) AS BED,
	pi_from_gmt(LAST_POS.EVENT_END_DT_TM, 'America/Chicago') AS COVID_DATETIME,
	LAST_POS.ENCNTR_ID,
	ENCNTR_ALIAS.ALIAS AS FIN,
    PERSON.NAME_FULL_FORMATTED AS NAME,
	pi_from_gmt(ENCOUNTER.REG_DT_TM, 'America/Chicago') AS ADMIT_DATETIME,
	TRUNC(((pi_from_gmt(ENCOUNTER.REG_DT_TM, 'America/Chicago')) - PERSON.BIRTH_DT_TM) / 365.25, 0) AS AGE,
	VENT_MODE.RESP_MODE AS CURR_RESP_MODE,
	pi_from_gmt(VENT_MODE.EVENT_END_DT_TM, 'America/Chicago') AS RESP_MODE_DATETIME,
	FIO2.FIO2,
	LABS_PIVOT.SPO2_PCT,
	LABS_PIVOT.O2_FLOW,
	LABS_PIVOT.EGFR,
	LABS_PIVOT.ALT,
	DIALYSIS.DIALYSIS,
	PRESSORS.NUM_PRESSORS
FROM
	DIALYSIS,
	ENCNTR_ALIAS,
	ENCOUNTER,
	FIO2,
	LABS_PIVOT,
	LAST_POS,
	PERSON,
	PRESSORS,
	VENT_MODE
WHERE	
	LAST_POS.ENCNTR_ID = ENCOUNTER.ENCNTR_ID
	AND ENCOUNTER.PERSON_ID = PERSON.PERSON_ID
	AND LAST_POS.ENCNTR_ID = ENCNTR_ALIAS.ENCNTR_ID
	AND ENCNTR_ALIAS.ENCNTR_ALIAS_TYPE_CD = 619 -- FIN NBR
	AND LAST_POS.ENCNTR_ID = DIALYSIS.ENCNTR_ID(+)
	AND LAST_POS.ENCNTR_ID = FIO2.ENCNTR_ID(+)
	AND LAST_POS.ENCNTR_ID = LABS_PIVOT.ENCNTR_ID(+)
	AND LAST_POS.ENCNTR_ID = PRESSORS.ENCNTR_ID(+)
	AND LAST_POS.ENCNTR_ID = VENT_MODE.ENCNTR_ID(+)
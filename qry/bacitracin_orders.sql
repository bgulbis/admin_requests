WITH BACIT_ORDS AS (
	SELECT
		ORDERS.ENCNTR_ID,
		ORDERS.ORDER_ID,
		ORDERS.ORIG_ORDER_DT_TM,
		ENCNTR_LOC_HIST.LOC_FACILITY_CD,
		ENCNTR_LOC_HIST.MED_SERVICE_CD,
		ENCNTR_LOC_HIST.ENCNTR_TYPE_CLASS_CD
	FROM 
		ENCNTR_LOC_HIST,
		ORDERS
	WHERE
		ORDERS.CATALOG_CD = 118893837 -- bacitracin
		AND ORDERS.ORIG_ORDER_DT_TM BETWEEN
			pi_to_gmt(TRUNC(ADD_MONTHS(SYSDATE, -6), 'MONTH'), pi_time_zone(2, @Variable('BOUSER')))
			AND pi_to_gmt(TRUNC(SYSDATE, 'MONTH') - (1 / 86400), pi_time_zone(2, @Variable('BOUSER')))
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
), SURGS AS (
	SELECT 
		BACIT_ORDS.ENCNTR_ID,
		SURGICAL_CASE.SURG_CASE_ID,
		SURGICAL_CASE.SURG_START_DT_TM,
		SURGICAL_CASE.SURG_STOP_DT_TM,
		SURG_CASE_PROCEDURE.SURG_PROC_CD,
		SURGICAL_CASE.SURG_AREA_CD,
		PRSNL.NAME_FULL_FORMATTED
	FROM
		BACIT_ORDS,
		PRSNL,
		SURGICAL_CASE,
		SURG_CASE_PROCEDURE
	WHERE
		BACIT_ORDS.ENCNTR_ID = SURGICAL_CASE.ENCNTR_ID
		AND SURGICAL_CASE.SURG_AREA_CD > 0
		AND SURGICAL_CASE.SURGEON_PRSNL_ID = PRSNL.PERSON_ID
		AND SURGICAL_CASE.SURG_CASE_ID = SURG_CASE_PROCEDURE.SURG_CASE_ID
		AND SURG_CASE_PROCEDURE.PRIMARY_PROC_IND = 1
)

SELECT
	BACIT_ORDS.ENCNTR_ID,
	pi_from_gmt(BACIT_ORDS.ORIG_ORDER_DT_TM, (pi_time_zone(1, @Variable('BOUSER')))) AS MED_DATETIME,
	pi_get_cv_display(BACIT_ORDS.LOC_FACILITY_CD) AS FACILITY,
	pi_get_cv_display(BACIT_ORDS.ENCNTR_TYPE_CLASS_CD) AS ENCNTR_TYPE,
	pi_get_cv_display(BACIT_ORDS.MED_SERVICE_CD) AS MED_SERVICE,
	pi_get_cv_display(SURGS.SURG_PROC_CD) AS SURGERY,
	pi_get_cv_display(SURGS.SURG_AREA_CD) AS SURG_AREA,
	SURGS.NAME_FULL_FORMATTED AS SURGEON	
FROM
	BACIT_ORDS,
	SURGS
WHERE
	BACIT_ORDS.ENCNTR_ID = SURGS.ENCNTR_ID
	AND BACIT_ORDS.ORIG_ORDER_DT_TM BETWEEN SURGS.SURG_START_DT_TM AND SURGS.SURG_STOP_DT_TM
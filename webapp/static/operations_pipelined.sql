-- Operations rewritten using PIPELINED TABLE FUNCTIONS
-- These are compatible with oracledb thin mode (no REF CURSOR issues)
-- Same business logic, different return mechanism

prompt Creating object types for pipelined functions

-- Type for Operation 2 results
CREATE OR REPLACE TYPE op2_result_typ AS OBJECT (
  id              NUMBER,
  name            VARCHAR2(200),
  data_type       VARCHAR2(100),
  density         NUMBER,
  donor_cf        CHAR(16),
  is_required     CHAR(1),
  condition       VARCHAR2(200)
);
/

CREATE OR REPLACE TYPE op2_result_tab AS TABLE OF op2_result_typ;
/

-- Type for Operation 3 results
CREATE OR REPLACE TYPE op3_result_typ AS OBJECT (
  treatment_id        NUMBER,
  treatment_name      VARCHAR2(200),
  success_percentage  NUMBER(5,2),
  drug_id             NUMBER,
  drug_name           VARCHAR2(200),
  allergy_id          NUMBER,
  allergy_name        VARCHAR2(200)
);
/

CREATE OR REPLACE TYPE op3_result_tab AS TABLE OF op3_result_typ;
/

-- Type for Operation 4 results
CREATE OR REPLACE TYPE op4_result_typ AS OBJECT (
  cf       CHAR(16),
  name     VARCHAR2(100),
  surname  VARCHAR2(100)
);
/

CREATE OR REPLACE TYPE op4_result_tab AS TABLE OF op4_result_typ;
/

-- Type for Operation 5 results
CREATE OR REPLACE TYPE op5_result_typ AS OBJECT (
  researcher_cf       CHAR(16),
  researcher_name     VARCHAR2(100),
  researcher_surname  VARCHAR2(100),
  future_work_id      NUMBER,
  future_work_title   VARCHAR2(300)
);
/

CREATE OR REPLACE TYPE op5_result_tab AS TABLE OF op5_result_typ;
/

prompt Creating pipelined table functions for operations

--------------------------------------------------------------------------------
-- Operation 2: List organs/tissues below density threshold (PIPELINED)
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION func_list_bio_below_density (
  p_threshold IN NUMBER
) RETURN op2_result_tab PIPELINED
AS
BEGIN
  FOR rec IN (
    SELECT b.id,
           b.name,
           b.data_type,
           b.density,
           DEREF(b.donor_ref).CF AS donor_cf,
           b.is_required,
           b.condition
      FROM biological_data_tab b
     WHERE b.density < p_threshold
  ) LOOP
    PIPE ROW(op2_result_typ(
      rec.id,
      rec.name,
      rec.data_type,
      rec.density,
      rec.donor_cf,
      rec.is_required,
      rec.condition
    ));
  END LOOP;
  RETURN;
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20022, 'Error in func_list_bio_below_density: ' || SQLERRM);
END;
/

--------------------------------------------------------------------------------
-- Operation 3: Treatment info with drugs and allergies (PIPELINED)
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION func_get_treatment_info (
  p_treatment_id IN NUMBER
) RETURN op3_result_tab PIPELINED
AS
BEGIN
  FOR rec IN (
    SELECT t.id                      AS treatment_id,
           t.name                    AS treatment_name,
           t.success_percentage,
           d.id                      AS drug_id,
           d.name                    AS drug_name,
           al.id                     AS allergy_id,
           al.name                   AS allergy_name
      FROM treatment_tab t
      LEFT JOIN assign_tab a
             ON a.treatment_ref = REF(t)
      LEFT JOIN drugs_tab d
             ON a.drug_ref = REF(d)
      LEFT JOIN cause_tab c
             ON c.drug_ref = a.drug_ref
      LEFT JOIN allergy_tab al
             ON c.allergy_ref = REF(al)
     WHERE t.id = p_treatment_id
  ) LOOP
    PIPE ROW(op3_result_typ(
      rec.treatment_id,
      rec.treatment_name,
      rec.success_percentage,
      rec.drug_id,
      rec.drug_name,
      rec.allergy_id,
      rec.allergy_name
    ));
  END LOOP;
  RETURN;
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20023, 'Error in func_get_treatment_info: ' || SQLERRM);
END;
/

--------------------------------------------------------------------------------
-- Operation 4: Donors with disease affecting required organs (PIPELINED)
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION func_list_donors_required_disease_with_fw (
  p_disease_id IN NUMBER
) RETURN op4_result_tab PIPELINED
AS
BEGIN
  FOR rec IN (
    SELECT DISTINCT DEREF(b.donor_ref).CF      AS cf,
                    DEREF(b.donor_ref).name    AS name,
                    DEREF(b.donor_ref).surname AS surname
      FROM affected_tab a
      JOIN disease_tab dis
        ON a.disease_ref = REF(dis)
       AND dis.id = p_disease_id
      JOIN biological_data_tab b
        ON a.bio_ref = REF(b)
     WHERE b.is_required = 'Y'
       AND EXISTS (
             SELECT 1
               FROM analyze_tab z
               JOIN future_work_tab f
                 ON f.exp_ref = z.exp_ref
              WHERE z.bio_ref = REF(b)
           )
  ) LOOP
    PIPE ROW(op4_result_typ(
      rec.cf,
      rec.name,
      rec.surname
    ));
  END LOOP;
  RETURN;
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20024, 'Error in func_list_donors_required_disease_with_fw: ' || SQLERRM);
END;
/

--------------------------------------------------------------------------------
-- Operation 5: Future works for top researchers (PIPELINED)
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION func_list_fw_for_top_researchers
RETURN op5_result_tab PIPELINED
AS
BEGIN
  FOR rec IN (
    WITH top_researchers AS (
      SELECT r.CF
      FROM researchers_tab r
      JOIN writes_tab w ON w.researcher_ref = REF(r)
      JOIN publication_tab p ON p.DOI = DEREF(w.publication_ref).DOI
      WHERE LOWER(p.quality) = 'top'
      GROUP BY r.CF
    )
    SELECT DISTINCT
           DEREF(c.researcher_ref).CF      AS researcher_cf,
           DEREF(c.researcher_ref).name    AS researcher_name,
           DEREF(c.researcher_ref).surname AS researcher_surname,
           DEREF(c.future_work_ref).id     AS future_work_id,
           DEREF(c.future_work_ref).title  AS future_work_title
      FROM consider_tab c
     WHERE DEREF(c.researcher_ref).CF IN (SELECT CF FROM top_researchers)
     ORDER BY researcher_surname, researcher_name, future_work_id
  ) LOOP
    PIPE ROW(op5_result_typ(
      rec.researcher_cf,
      rec.researcher_name,
      rec.researcher_surname,
      rec.future_work_id,
      rec.future_work_title
    ));
  END LOOP;
  RETURN;
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20025, 'Error in func_list_fw_for_top_researchers: ' || SQLERRM);
END;
/

prompt Pipelined functions created successfully

-- Test queries (comment out after testing)
-- SELECT * FROM TABLE(func_list_bio_below_density(1.0));
-- SELECT * FROM TABLE(func_get_treatment_info(1));
-- SELECT * FROM TABLE(func_list_donors_required_disease_with_fw(1));
-- SELECT * FROM TABLE(func_list_fw_for_top_researchers());

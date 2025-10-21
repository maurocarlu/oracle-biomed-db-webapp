-- Operations and utility procedures for the schema
--
-- Operation 1: Recording an organ or tissue (BiologicalData)
-- Operation 2: Print all organ/tissue below a density threshold
-- Operation 3: Info on a specific Treatment, its Drugs and linked Allergies
-- Operation 4: Donors with a specific disease affecting only life-required organs/tissues
--              for which the system provided useful suggestions (Future Works)
-- Operation 5: All useful suggestions provided to researchers with top-quality journals
--
-- Notes:
-- - Listing procedures return a SYS_REFCURSOR for client-side fetching/printing.
-- - Operation 1 follows the example style and performs a COMMIT upon success.
-- - Case-insensitive comparisons are used where appropriate (e.g., quality, disease name).

prompt Creating procedures and functions for domain operations

--------------------------------------------------------------------------------
-- Operation 1: Recording an organ or tissue
--------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE proc_record_biological_data (
  p_id           IN NUMBER,
  p_name         IN VARCHAR2,
  p_condition    IN VARCHAR2,   -- 'control' | 'disease'
  p_is_required  IN CHAR,       -- 'Y' | 'N'
  p_description  IN CLOB,
  p_position     IN VARCHAR2,
  p_data_type    IN VARCHAR2,   -- 'organ' | 'tissue'
  p_density      IN NUMBER,
  p_donor_cf     IN CHAR
) AS
  v_donor_ref REF donor_typ;
BEGIN
  -- Check donor existence and get REF
  SELECT REF(d)
    INTO v_donor_ref
    FROM donors_tab d
   WHERE d.CF = p_donor_cf;

  INSERT INTO biological_data_tab
  VALUES (
    biological_data_typ(
      p_id,
      p_name,
      p_condition,
      p_is_required,
      p_description,
      p_position,
      p_data_type,
      p_density,
      v_donor_ref
    )
  );

  COMMIT;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20020, 'Donor not found for provided CF');
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20021, 'Error in proc_record_biological_data: ' || SQLERRM);
END;
/

--------------------------------------------------------------------------------
-- Operation 2: Print all the organ and tissues below a certain density threshold (once a month)
-- Returns: id, name, data_type, density, donor_cf, is_required, condition
--------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE proc_list_bio_below_density (
  p_threshold IN NUMBER,
  p_result    OUT SYS_REFCURSOR
) AS
BEGIN
  OPEN p_result FOR
    SELECT b.id,
           b.name,
           b.data_type,
           b.density,
           DEREF(b.donor_ref).CF AS donor_cf,
           b.is_required,
           b.condition
      FROM biological_data_tab b
     WHERE b.density < p_threshold;
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20022, 'Error in proc_list_bio_below_density: ' || SQLERRM);
END;
/



--------------------------------------------------------------------------------
-- Operation 3: Request information on a specific cure (Treatment), its list of
--              drugs and possible linked allergies (once a day)
-- Input: p_treatment_id (Treatment.id)
-- Returns one row per (drug, allergy) combination, with treatment details
--------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE proc_get_treatment_info (
  p_treatment_id IN NUMBER,
  p_result       OUT SYS_REFCURSOR
) AS
BEGIN
  OPEN p_result FOR
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
     WHERE t.id = p_treatment_id;
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20023, 'Error in proc_get_treatment_info: ' || SQLERRM);
END;
/

--------------------------------------------------------------------------------
-- Operation 4: Donors with a specific disease affecting only life-required organs/tissues
--              for which the system provided useful suggestions (Future Works)
-- Input: p_disease_id (disease_tab.id)
-- Returns: donor (CF, name, surname)
--------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE proc_list_donors_required_disease_with_fw (
  p_disease_id IN NUMBER,
  p_result     OUT SYS_REFCURSOR
) AS
BEGIN
  OPEN p_result FOR
    SELECT DISTINCT DEREF(b.donor_ref).CF      AS CF,
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
           );
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20024, 'Error in proc_list_donors_required_disease_with_fw: ' || SQLERRM);
END;
/

--------------------------------------------------------------------------------
-- Operation 5: All useful suggestions (Future Works) provided to only researchers
--              with top quality journals published (once a month)
-- Returns: future work id, title, researcher (CF, name, surname)
--------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE proc_list_fw_for_top_researchers (
  p_result OUT SYS_REFCURSOR
) AS
BEGIN
  OPEN p_result FOR
    SELECT
      f.id      AS future_work_id,
      f.title   AS future_work_title,
      r.CF      AS researcher_cf,
      r.name    AS researcher_name,
      r.surname AS researcher_surname
    FROM consider_tab c
    JOIN future_work_tab f
      ON c.future_work_ref = REF(f)
    JOIN (
        SELECT DISTINCT w.researcher_ref
        FROM writes_tab w
        JOIN publication_tab p
          ON w.publication_ref = REF(p)
        WHERE p.quality = 'top'
    ) top_researchers
      ON c.researcher_ref = top_researchers.researcher_ref
    JOIN researchers_tab r
      ON c.researcher_ref = REF(r);
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20025,
      'Error in proc_list_fw_for_top_researchers: ' || SQLERRM);
END;
/

prompt Procedures created.

prompt Running operation examples (SQL*Plus / SQLcl)
SET SERVEROUTPUT ON
WHENEVER SQLERROR CONTINUE

-- Op1 example: try to insert a sample BiologicalData for the first donor (if any)
DECLARE
  v_cf donors_tab.CF%TYPE;
BEGIN
  SELECT CF INTO v_cf FROM donors_tab WHERE ROWNUM = 1;
  proc_record_biological_data(
    p_id           => 1000001,
    p_name         => 'Sample organ',
    p_condition    => 'disease',
    p_is_required  => 'Y',
    p_description  => 'Example insert from operations.sql',
    p_position     => 'Sample position',
    p_data_type    => 'organ',
    p_density      => 1.00,
    p_donor_cf     => v_cf
  );
  DBMS_OUTPUT.PUT_LINE('Op1: Inserted biological_data for donor ' || v_cf);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Op1: Skipped (no donors present)');
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Op1: Error: ' || SQLERRM);
END;
/

-- Cursor for listing examples
VAR rc REFCURSOR

-- Op2 example
EXEC proc_list_bio_below_density(1.0, :rc)
PRINT rc

-- Op3 example (treatment id = 10)
EXEC proc_get_treatment_info(10, :rc)
PRINT rc

-- Op4 example (disease by id)
EXEC proc_list_donors_required_disease_with_fw(3, :rc)
PRINT rc

-- Op5 example
EXEC proc_list_fw_for_top_researchers(:rc)
PRINT rc


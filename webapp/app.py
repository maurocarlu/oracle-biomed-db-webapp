from flask import Flask, render_template, request, redirect, url_for, flash, jsonify
import oracledb
from config import Config
from datetime import datetime

app = Flask(__name__)
app.secret_key = ' '

def get_db_connection():
    """Create and return a database connection"""
    try:
        connection = oracledb.connect(
            user=Config.DB_USER,
            password=Config.DB_PASSWORD,
            dsn=Config.get_dsn()
        )
        return connection
    except Exception as e:
        print(f"Error connecting to database: {e}")
        raise

@app.route('/')
def index():
    """Home page with navigation"""
    return render_template('index.html')

@app.route('/assignations')
def assignations():
    """Assignations overview page"""
    return render_template('assignations.html')

# ==================== DONORS ====================
@app.route('/donors')
def donors():
    """List all donors"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT CF, name, surname, birth, sex, age
        FROM donors_tab
        ORDER BY surname, name
    """)
    donors = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('donors.html', donors=donors)

@app.route('/donors/add', methods=['GET', 'POST'])
def add_donor():
    """Add a new donor"""
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            cf = request.form['cf']
            name = request.form['name']
            surname = request.form['surname']
            birth = request.form['birth']
            sex = request.form['sex']
            age = request.form['age']
            
            cursor.execute("""
                INSERT INTO donors_tab VALUES (
                    donor_typ(:cf, :name, :surname, TO_DATE(:birth, 'YYYY-MM-DD'), :sex, :age)
                )
            """, {
                'cf': cf,
                'name': name,
                'surname': surname,
                'birth': birth,
                'sex': sex,
                'age': age
            })
            
            conn.commit()
            cursor.close()
            conn.close()
            
            flash('Donor added successfully!', 'success')
            return redirect(url_for('donors'))
        except Exception as e:
            flash(f'Error adding donor: {str(e)}', 'error')
    
    return render_template('add_donor.html')

# ==================== RESEARCHERS ====================
@app.route('/researchers')
def researchers():
    """List all researchers"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT CF, name, surname, birth
        FROM researchers_tab
        ORDER BY surname, name
    """)
    researchers = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('researchers.html', researchers=researchers)

@app.route('/researchers/add', methods=['GET', 'POST'])
def add_researcher():
    """Add a new researcher"""
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            cf = request.form['cf']
            name = request.form['name']
            surname = request.form['surname']
            birth = request.form['birth']
            
            cursor.execute("""
                INSERT INTO researchers_tab VALUES (
                    researcher_typ(:cf, :name, :surname, TO_DATE(:birth, 'YYYY-MM-DD'))
                )
            """, {
                'cf': cf,
                'name': name,
                'surname': surname,
                'birth': birth
            })
            
            conn.commit()
            cursor.close()
            conn.close()
            
            flash('Researcher added successfully!', 'success')
            return redirect(url_for('researchers'))
        except Exception as e:
            flash(f'Error adding researcher: {str(e)}', 'error')
    
    return render_template('add_researcher.html')

# ==================== DISEASES ====================
@app.route('/diseases')
def diseases():
    """List all diseases"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id, name, discovery_date, description
        FROM disease_tab
        ORDER BY name
    """)
    raw_diseases = cursor.fetchall()
    
    # Convert CLOB to string
    diseases = []
    for row in raw_diseases:
        diseases.append((
            row[0],  # id
            row[1],  # name
            row[2],  # discovery_date
            row[3].read()[:100] if row[3] else 'N/A'  # description (CLOB)
        ))
    
    cursor.close()
    conn.close()
    return render_template('diseases.html', diseases=diseases)

@app.route('/diseases/add', methods=['GET', 'POST'])
def add_disease():
    """Add a new disease"""
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Get next ID
            cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM disease_tab")
            disease_id = cursor.fetchone()[0]
            
            name = request.form['name']
            discovery_date = request.form['discovery_date']
            description = request.form['description']
            
            cursor.execute("""
                INSERT INTO disease_tab VALUES (
                    disease_typ(:id, :name, TO_DATE(:discovery_date, 'YYYY-MM-DD'), :description)
                )
            """, {
                'id': disease_id,
                'name': name,
                'discovery_date': discovery_date,
                'description': description
            })
            
            conn.commit()
            cursor.close()
            conn.close()
            
            flash('Disease added successfully!', 'success')
            return redirect(url_for('diseases'))
        except Exception as e:
            flash(f'Error adding disease: {str(e)}', 'error')
    
    return render_template('add_disease.html')

# ==================== BIOLOGICAL DATA ====================
@app.route('/biological_data')
def biological_data():
    """List all biological data"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT b.id, b.name, b.data_type, b.condition, b.is_required, 
               b.density, b.position, DEREF(b.donor_ref).CF as donor_cf
        FROM biological_data_tab b
        ORDER BY b.id
    """)
    bio_data = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('biological_data.html', bio_data=bio_data)

@app.route('/biological_data/add', methods=['GET', 'POST'])
def add_biological_data():
    """Add biological data using the stored procedure"""
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Get next ID
            cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM biological_data_tab")
            bio_id = cursor.fetchone()[0]
            
            # Call the stored procedure
            cursor.callproc('proc_record_biological_data', [
                bio_id,
                request.form['name'],
                request.form['condition'],
                request.form['is_required'],
                request.form['description'],
                request.form['position'],
                request.form['data_type'],
                float(request.form['density']),
                request.form['donor_cf']
            ])
            
            cursor.close()
            conn.close()
            
            flash('Biological data added successfully!', 'success')
            return redirect(url_for('biological_data'))
        except Exception as e:
            flash(f'Error adding biological data: {str(e)}', 'error')
    
    # Get list of donors for dropdown
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT CF, name, surname FROM donors_tab ORDER BY surname, name")
    donors = cursor.fetchall()
    cursor.close()
    conn.close()
    
    return render_template('add_biological_data.html', donors=donors)

# ==================== TREATMENTS ====================
@app.route('/treatments')
def treatments():
    """List all treatments"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id, name, success_percentage
        FROM treatment_tab
        ORDER BY name
    """)
    treatments = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('treatments.html', treatments=treatments)

@app.route('/treatments/add', methods=['GET', 'POST'])
def add_treatment():
    """Add a new treatment"""
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Get next ID
            cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM treatment_tab")
            treatment_id = cursor.fetchone()[0]
            
            name = request.form['name']
            success_percentage = request.form['success_percentage']
            
            cursor.execute("""
                INSERT INTO treatment_tab VALUES (
                    treatment_typ(:id, :name, :success_percentage)
                )
            """, {
                'id': treatment_id,
                'name': name,
                'success_percentage': success_percentage
            })
            
            conn.commit()
            cursor.close()
            conn.close()
            
            flash('Treatment added successfully!', 'success')
            return redirect(url_for('treatments'))
        except Exception as e:
            flash(f'Error adding treatment: {str(e)}', 'error')
    
    return render_template('add_treatment.html')

# ==================== DRUGS ====================
@app.route('/drugs')
def drugs():
    """List all drugs"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id, name, description
        FROM drugs_tab
        ORDER BY name
    """)
    raw_drugs = cursor.fetchall()
    
    # Convert CLOB to string
    drugs_list = []
    for row in raw_drugs:
        drugs_list.append((
            row[0],  # id
            row[1],  # name
            row[2].read()[:100] if row[2] else 'N/A'  # description (CLOB)
        ))
    
    cursor.close()
    conn.close()
    return render_template('drugs.html', drugs=drugs_list)

@app.route('/drugs/add', methods=['GET', 'POST'])
def add_drug():
    """Add a new drug"""
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Get next ID
            cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM drugs_tab")
            drug_id = cursor.fetchone()[0]
            
            name = request.form['name']
            description = request.form['description']
            
            cursor.execute("""
                INSERT INTO drugs_tab VALUES (
                    drugs_typ(:id, :name, :description)
                )
            """, {
                'id': drug_id,
                'name': name,
                'description': description
            })
            
            conn.commit()
            cursor.close()
            conn.close()
            
            flash('Drug added successfully!', 'success')
            return redirect(url_for('drugs'))
        except Exception as e:
            flash(f'Error adding drug: {str(e)}', 'error')
    
    return render_template('add_drug.html')

# ==================== PUBLICATIONS ====================
@app.route('/publications')
def publications():
    """List all publications"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT DOI, publisher, quality, title
        FROM publication_tab
        ORDER BY title
    """)
    publications = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('publications.html', publications=publications)

@app.route('/publications/add', methods=['GET', 'POST'])
def add_publication():
    """Add a new publication"""
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            doi = request.form.get('doi')
            title = request.form.get('title')
            quality = request.form.get('quality')
            publisher = request.form.get('publisher')
            
            # publication_typ has (DOI, publisher, quality, title) - NO id, year, journal
            cursor.execute("""
                INSERT INTO publication_tab VALUES (
                    publication_typ(:doi, :publisher, :quality, :title)
                )
            """, {
                'doi': doi,
                'publisher': publisher,
                'quality': quality,
                'title': title
            })
            
            conn.commit()
            cursor.close()
            conn.close()
            
            flash('Publication added successfully!', 'success')
            return redirect(url_for('publications'))
        except Exception as e:
            flash(f'Error adding publication: {str(e)}', 'error')
    
    return render_template('add_publication.html')

# ==================== ALLERGIES ====================
@app.route('/allergies')
def allergies():
    """List all allergies"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id, name
        FROM allergy_tab
        ORDER BY name
    """)
    allergies = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('allergies.html', allergies=allergies)

@app.route('/allergies/add', methods=['GET', 'POST'])
def add_allergy():
    """Add a new allergy"""
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Get next ID
            cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM allergy_tab")
            allergy_id = cursor.fetchone()[0]
            
            name = request.form.get('name')
            
            # allergy_typ has only (id, name) - NO description
            cursor.execute("""
                INSERT INTO allergy_tab VALUES (
                    allergy_typ(:id, :name)
                )
            """, {
                'id': allergy_id,
                'name': name
            })
            
            conn.commit()
            cursor.close()
            conn.close()
            
            flash('Allergy added successfully!', 'success')
            return redirect(url_for('allergies'))
        except Exception as e:
            flash(f'Error adding allergy: {str(e)}', 'error')
    
    return render_template('add_allergy.html')

# ==================== EXPERIMENTS ====================
@app.route('/experiments')
def experiments():
    """List all experiments"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT id, exper_date, is_positive, 
               SUBSTR(effect_description, 1, 100) as effect_desc,
               DEREF(disease_ref).id AS disease_id,
               DEREF(treatment_ref).id AS treatment_id
        FROM experiment_tab
        ORDER BY exper_date DESC
    """)
    experiments = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('experiments.html', experiments=experiments)

@app.route('/experiments/add', methods=['GET', 'POST'])
def add_experiment():
    """Add a new experiment"""
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Get next ID
            cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM experiment_tab")
            exp_id = cursor.fetchone()[0]
            
            exper_date = request.form.get('exper_date')
            is_positive = request.form.get('is_positive')
            effect_description = request.form.get('effect_description')
            disease_id = request.form.get('disease_id')
            treatment_id = request.form.get('treatment_id')
            
            # Insert using subquery to get REFs inline (avoids DPY-3006 error)
            cursor.execute("""
                INSERT INTO experiment_tab
                SELECT experiment_typ(
                    :id, 
                    TO_DATE(:exper_date, 'YYYY-MM-DD'), 
                    :is_positive, 
                    :effect_description,
                    (SELECT REF(d) FROM disease_tab d WHERE d.id = :disease_id),
                    (SELECT REF(t) FROM treatment_tab t WHERE t.id = :treatment_id)
                ) FROM DUAL
            """, {
                'id': exp_id,
                'exper_date': exper_date,
                'is_positive': is_positive,
                'effect_description': effect_description,
                'disease_id': int(disease_id),
                'treatment_id': int(treatment_id)
            })
            
            conn.commit()
            cursor.close()
            conn.close()
            
            flash('Experiment added successfully!', 'success')
            return redirect(url_for('experiments'))
        except Exception as e:
            flash(f'Error adding experiment: {str(e)}', 'error')
    
    # GET request - load diseases and treatments for dropdown
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, name FROM disease_tab ORDER BY name")
    diseases = cursor.fetchall()
    cursor.execute("SELECT id, name FROM treatment_tab ORDER BY name")
    treatments = cursor.fetchall()
    cursor.close()
    conn.close()
    
    return render_template('add_experiment.html', diseases=diseases, treatments=treatments)

# ==================== FUTURE WORKS ====================
@app.route('/future_works')
def future_works():
    """List all future works"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT f.id, f.title, 
               DEREF(f.exp_ref).id AS exp_id,
               DEREF(f.pub_ref).DOI AS pub_doi
        FROM future_work_tab f
        ORDER BY f.id
    """)
    future_works = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('future_works.html', future_works=future_works)

@app.route('/future_works/add', methods=['GET', 'POST'])
def add_future_work():
    """Add a new future work"""
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Get next ID
            cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM future_work_tab")
            fw_id = cursor.fetchone()[0]
            
            title = request.form.get('title')
            exp_id = request.form.get('exp_id')
            pub_doi = request.form.get('pub_doi')
            
            # Insert using subquery to get REFs inline (avoids DPY-3006 error)
            cursor.execute("""
                INSERT INTO future_work_tab
                SELECT future_work_typ(
                    :id, 
                    :title,
                    (SELECT REF(e) FROM experiment_tab e WHERE e.id = :exp_id),
                    (SELECT REF(p) FROM publication_tab p WHERE p.DOI = :pub_doi)
                ) FROM DUAL
            """, {
                'id': fw_id,
                'title': title,
                'exp_id': int(exp_id),
                'pub_doi': pub_doi
            })
            
            conn.commit()
            cursor.close()
            conn.close()
            
            flash('Future work added successfully!', 'success')
            return redirect(url_for('future_works'))
        except Exception as e:
            flash(f'Error adding future work: {str(e)}', 'error')
    
    # GET request - load experiments and publications for dropdown
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, exper_date FROM experiment_tab ORDER BY exper_date DESC")
    experiments = cursor.fetchall()
    cursor.execute("SELECT DOI, title FROM publication_tab ORDER BY title")
    publications = cursor.fetchall()
    cursor.close()
    conn.close()
    
    return render_template('add_future_work.html', experiments=experiments, publications=publications)

# ==================== OPERATIONS ====================
@app.route('/operations')
def operations():
    """Operations page"""
    return render_template('operations.html')

@app.route('/operations/op2', methods=['GET', 'POST'])
def operation_2():
    """Operation 2: List organs/tissues below density threshold"""
    results = None
    threshold = ''
    
    if request.method == 'POST':
        try:
            threshold = request.form.get('threshold', '')
            
            if not threshold:
                flash('Please enter a threshold value', 'error')
                return render_template('operation_2.html', results=None, threshold='')
                
            threshold_val = float(threshold)
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Call pipelined table function
            cursor.execute("""
                SELECT * FROM TABLE(func_list_bio_below_density(:threshold))
            """, {'threshold': threshold_val})
            
            results = cursor.fetchall()
            
            cursor.close()
            conn.close()
        except oracledb.Error as e:
            error_obj, = e.args
            flash(f'Database error: {error_obj.message}', 'error')
        except Exception as e:
            flash(f'Error executing operation: {str(e)}', 'error')
    
    return render_template('operation_2.html', results=results, threshold=threshold)

@app.route('/operations/op3', methods=['GET', 'POST'])
def operation_3():
    """Operation 3: Get treatment info with drugs and allergies"""
    results = None
    treatment_id = ''
    treatments = []
    
    # Get list of treatments for dropdown
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT id, name FROM treatment_tab ORDER BY name")
        treatments = cursor.fetchall()
        cursor.close()
        conn.close()
    except Exception as e:
        flash(f'Error loading treatments: {str(e)}', 'error')
    
    if request.method == 'POST':
        try:
            treatment_id = request.form.get('treatment_id', '')
            
            if not treatment_id:
                flash('Please select a treatment', 'error')
                return render_template('operation_3.html', results=None, treatments=treatments, treatment_id='')
                
            treatment_id_val = int(treatment_id)
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Call pipelined table function
            cursor.execute("""
                SELECT * FROM TABLE(func_get_treatment_info(:treatment_id))
            """, {'treatment_id': treatment_id_val})
            
            results = cursor.fetchall()
            
            cursor.close()
            conn.close()
        except oracledb.Error as e:
            error_obj, = e.args
            flash(f'Database error: {error_obj.message}', 'error')
        except Exception as e:
            flash(f'Error executing operation: {str(e)}', 'error')
    
    return render_template('operation_3.html', results=results, treatments=treatments, treatment_id=treatment_id)

@app.route('/operations/op4', methods=['GET', 'POST'])
def operation_4():
    """Operation 4: Donors with disease affecting required organs with future works"""
    results = None
    disease_id = ''
    diseases = []
    
    # Get list of diseases for dropdown
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT id, name FROM disease_tab ORDER BY name")
        diseases = cursor.fetchall()
        cursor.close()
        conn.close()
    except Exception as e:
        flash(f'Error loading diseases: {str(e)}', 'error')
    
    if request.method == 'POST':
        try:
            disease_id = request.form.get('disease_id', '')
            
            if not disease_id:
                flash('Please select a disease', 'error')
                return render_template('operation_4.html', results=None, diseases=diseases, disease_id='')
                
            disease_id_val = int(disease_id)
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Call pipelined table function
            cursor.execute("""
                SELECT * FROM TABLE(func_list_donors_required_disease_with_fw(:disease_id))
            """, {'disease_id': disease_id_val})
            
            results = cursor.fetchall()
            
            cursor.close()
            conn.close()
        except oracledb.Error as e:
            error_obj, = e.args
            flash(f'Database error: {error_obj.message}', 'error')
        except Exception as e:
            flash(f'Error executing operation: {str(e)}', 'error')
    
    return render_template('operation_4.html', results=results, diseases=diseases, disease_id=disease_id)

@app.route('/operations/op5')
def operation_5():
    """Operation 5: Future works for top researchers"""
    results = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Call pipelined table function
        cursor.execute("SELECT * FROM TABLE(func_list_fw_for_top_researchers())")
        results = cursor.fetchall()
        
        cursor.close()
        conn.close()
    except oracledb.Error as e:
        error_obj, = e.args
        flash(f'Database error: {error_obj.message}', 'error')
    except Exception as e:
        flash(f'Error executing operation: {str(e)}', 'error')
    
    return render_template('operation_5.html', results=results)

# ==================== ASSOCIATION TABLES ====================

# ASSIGN (Treatment-Drug)
@app.route('/assign')
def assign():
    """List all treatment-drug assignments"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT a.id, 
               DEREF(a.treatment_ref).id AS treatment_id,
               DEREF(a.treatment_ref).name AS treatment_name,
               DEREF(a.drug_ref).id AS drug_id,
               DEREF(a.drug_ref).name AS drug_name
        FROM assign_tab a
        ORDER BY a.id
    """)
    assigns = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('assign.html', assigns=assigns)

@app.route('/assign/add', methods=['GET', 'POST'])
def add_assign():
    """Add treatment-drug assignment"""
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM assign_tab")
            assign_id = cursor.fetchone()[0]
            
            treatment_id = request.form['treatment_id']
            drug_id = request.form['drug_id']
            
            cursor.execute("""
                INSERT INTO assign_tab
                SELECT assign_typ(:id, REF(t), REF(d))
                FROM treatment_tab t, drugs_tab d
                WHERE t.id = :tid AND d.id = :did
            """, {'id': assign_id, 'tid': treatment_id, 'did': drug_id})
            
            conn.commit()
            cursor.close()
            conn.close()
            
            flash('Assignment added successfully!', 'success')
            return redirect(url_for('assign'))
        except Exception as e:
            flash(f'Error adding assignment: {str(e)}', 'error')
    
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, name FROM treatment_tab ORDER BY name")
    treatments = cursor.fetchall()
    cursor.execute("SELECT id, name FROM drugs_tab ORDER BY name")
    drugs = cursor.fetchall()
    cursor.close()
    conn.close()
    
    return render_template('add_assign.html', treatments=treatments, drugs=drugs)

# ==================== WRITES (Researcher-Publication) ====================
@app.route('/writes')
def writes():
    """List all researcher-publication associations"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT w.id,
               DEREF(w.researcher_ref).CF AS researcher_cf,
               DEREF(w.researcher_ref).name AS researcher_name,
               DEREF(w.researcher_ref).surname AS researcher_surname,
               DEREF(w.publication_ref).DOI AS pub_doi,
               DEREF(w.publication_ref).title AS pub_title
        FROM writes_tab w
        ORDER BY w.id
    """)
    writes = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('writes.html', writes=writes)

@app.route('/writes/add', methods=['GET', 'POST'])
def add_writes():
    """Add a new researcher-publication association"""
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            researcher_cf = request.form.get('researcher_cf')
            publication_doi = request.form.get('publication_doi')
            
            # Get next ID
            cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM writes_tab")
            next_id = cursor.fetchone()[0]
            
            # Insert using subquery to get REFs inline (avoids DPY-3006 error)
            cursor.execute("""
                INSERT INTO writes_tab
                SELECT writes_typ(
                    :id,
                    (SELECT REF(p) FROM publication_tab p WHERE p.DOI = :doi),
                    (SELECT REF(r) FROM researchers_tab r WHERE r.CF = :cf)
                ) FROM DUAL
            """, {
                'id': next_id,
                'doi': publication_doi,
                'cf': researcher_cf
            })
            
            conn.commit()
            cursor.close()
            conn.close()
            
            flash('Publication assignment added successfully!', 'success')
            return redirect(url_for('writes'))
        except Exception as e:
            flash(f'Error adding assignment: {str(e)}', 'error')
    
    # GET request - load data for form
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT CF, name, surname FROM researchers_tab ORDER BY name")
    researchers = cursor.fetchall()
    cursor.execute("SELECT DOI, title FROM publication_tab ORDER BY title")
    publications = cursor.fetchall()
    cursor.close()
    conn.close()
    
    return render_template('add_writes.html', researchers=researchers, publications=publications)

# ==================== AFFECTED (BiologicalData-Disease) ====================
@app.route('/affected')
def affected():
    """List all biological data-disease associations"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT a.id,
               DEREF(a.bio_ref).id AS bio_id,
               DEREF(a.bio_ref).name AS bio_name,
               DEREF(a.disease_ref).id AS disease_id,
               DEREF(a.disease_ref).name AS disease_name
        FROM affected_tab a
        ORDER BY a.id
    """)
    affected = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('affected.html', affected=affected)

@app.route('/affected/add', methods=['GET', 'POST'])
def add_affected():
    """Add a new biological data-disease association"""
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            disease_id = request.form.get('disease_id')
            bio_id = request.form.get('bio_id')
            
            # Get next ID
            cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM affected_tab")
            next_id = cursor.fetchone()[0]
            
            # Insert using subquery to get REFs inline (avoids DPY-3006 error)
            cursor.execute("""
                INSERT INTO affected_tab
                SELECT affected_typ(
                    :id,
                    (SELECT REF(b) FROM biological_data_tab b WHERE b.id = :bio_id),
                    (SELECT REF(d) FROM disease_tab d WHERE d.id = :disease_id)
                ) FROM DUAL
            """, {
                'id': next_id,
                'bio_id': int(bio_id),
                'disease_id': int(disease_id)
            })
            
            conn.commit()
            cursor.close()
            conn.close()
            
            flash('Disease-BioData link added successfully!', 'success')
            return redirect(url_for('affected'))
        except Exception as e:
            flash(f'Error adding link: {str(e)}', 'error')
    
    # GET request - load data for form
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, name FROM disease_tab ORDER BY name")
    diseases = cursor.fetchall()
    cursor.execute("SELECT id, name, condition FROM biological_data_tab WHERE LOWER(condition) = 'disease' ORDER BY name")
    biological_data = cursor.fetchall()
    cursor.close()
    conn.close()
    
    return render_template('add_affected.html', diseases=diseases, biological_data=biological_data)

# ==================== CAUSE (Drug-Allergy) ====================
@app.route('/cause')
def cause():
    """List all drug-allergy associations"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT c.id,
               DEREF(c.drug_ref).id AS drug_id,
               DEREF(c.drug_ref).name AS drug_name,
               DEREF(c.allergy_ref).id AS allergy_id,
               DEREF(c.allergy_ref).name AS allergy_name
        FROM cause_tab c
        ORDER BY c.id
    """)
    causes = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('cause.html', causes=causes)

@app.route('/cause/add', methods=['GET', 'POST'])
def add_cause():
    """Add a new drug-allergy association"""
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            drug_id = request.form.get('drug_id')
            allergy_id = request.form.get('allergy_id')
            
            # Get next ID
            cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM cause_tab")
            next_id = cursor.fetchone()[0]
            
            # Insert using subquery to get REFs inline (avoids DPY-3006 error)
            cursor.execute("""
                INSERT INTO cause_tab
                SELECT cause_typ(
                    :id,
                    (SELECT REF(d) FROM drugs_tab d WHERE d.id = :drug_id),
                    (SELECT REF(a) FROM allergy_tab a WHERE a.id = :allergy_id)
                ) FROM DUAL
            """, {
                'id': next_id,
                'drug_id': int(drug_id),
                'allergy_id': int(allergy_id)
            })
            
            conn.commit()
            cursor.close()
            conn.close()
            
            flash('Drug-Allergy link added successfully!', 'success')
            return redirect(url_for('cause'))
        except Exception as e:
            flash(f'Error adding link: {str(e)}', 'error')
    
    # GET request - load data for form
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, name FROM drugs_tab ORDER BY name")
    drugs = cursor.fetchall()
    cursor.execute("SELECT id, name FROM allergy_tab ORDER BY name")
    allergies = cursor.fetchall()
    cursor.close()
    conn.close()
    
    return render_template('add_cause.html', drugs=drugs, allergies=allergies)

# ==================== ANALYZE (BiologicalData-Experiment) ====================
@app.route('/analyze')
def analyze():
    """List all biological data-experiment associations"""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT a.id,
               DEREF(a.bio_ref).id AS bio_id,
               DEREF(a.bio_ref).name AS bio_name,
               DEREF(a.exp_ref).id AS exp_id,
               DEREF(a.exp_ref).exper_date AS exp_date
        FROM analyze_tab a
        ORDER BY a.id
    """)
    analyzes = cursor.fetchall()
    cursor.close()
    conn.close()
    return render_template('analyze.html', analyzes=analyzes)

@app.route('/analyze/add', methods=['GET', 'POST'])
def add_analyze():
    """Add a new biological data-experiment association"""
    if request.method == 'POST':
        try:
            conn = get_db_connection()
            cursor = conn.cursor()
            
            bio_id = request.form.get('bio_id')
            exp_id = request.form.get('exp_id')
            
            # Get next ID
            cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM analyze_tab")
            next_id = cursor.fetchone()[0]
            
            # Insert using subquery to get REFs inline (avoids DPY-3006 error)
            cursor.execute("""
                INSERT INTO analyze_tab
                SELECT analyze_typ(
                    :id,
                    (SELECT REF(b) FROM biological_data_tab b WHERE b.id = :bio_id),
                    (SELECT REF(e) FROM experiment_tab e WHERE e.id = :exp_id)
                ) FROM DUAL
            """, {
                'id': next_id,
                'bio_id': int(bio_id),
                'exp_id': int(exp_id)
            })
            
            conn.commit()
            cursor.close()
            conn.close()
            
            flash('BioData-Experiment link added successfully!', 'success')
            return redirect(url_for('analyze'))
        except Exception as e:
            flash(f'Error adding link: {str(e)}', 'error')
    
    # GET request - load data for form
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Get biological data with their affected diseases
    cursor.execute("""
        SELECT DISTINCT b.id, 
               b.name, 
               b.condition,
               LISTAGG(DEREF(a.disease_ref).name, ', ') WITHIN GROUP (ORDER BY DEREF(a.disease_ref).name) AS diseases
        FROM biological_data_tab b
        LEFT JOIN affected_tab a ON a.bio_ref = REF(b)
        WHERE LOWER(b.condition) = 'disease'
        GROUP BY b.id, b.name, b.condition
        ORDER BY b.name
    """)
    biological_data = cursor.fetchall()
    
    # Get experiments with their disease info
    cursor.execute("""
        SELECT e.id, 
               e.exper_date,
               DEREF(e.disease_ref).id AS disease_id,
               DEREF(e.disease_ref).name AS disease_name
        FROM experiment_tab e
        ORDER BY e.exper_date DESC
    """)
    experiments = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    return render_template('add_analyze.html', biological_data=biological_data, experiments=experiments)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

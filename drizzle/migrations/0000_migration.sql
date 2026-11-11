CREATE OR REPLACE FUNCTION public.arr_text(arr text[]) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = public AS $$ SELECT coalesce(array_to_string(arr, ' '), '') $$;

CREATE TABLE public.articles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  slug text NOT NULL UNIQUE,
  category text NOT NULL CHECK (category IN ('condition','medication','wellness')),
  topic text NOT NULL,
  summary text NOT NULL,
  body text NOT NULL,
  symptoms text[] NOT NULL DEFAULT '{}',
  causes text[] NOT NULL DEFAULT '{}',
  prevention text[] NOT NULL DEFAULT '{}',
  treatment_overview text,
  keywords text[] NOT NULL DEFAULT '{}',
  source_name text NOT NULL,
  source_url text NOT NULL,
  published_at date,
  last_reviewed_at date,
  language text NOT NULL DEFAULT 'en',
  review_status text NOT NULL DEFAULT 'provisional' CHECK (review_status IN ('provisional','verified','retired')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  search_vector tsvector GENERATED ALWAYS AS (
    setweight(to_tsvector('english'::regconfig, coalesce(title,'')), 'A') ||
    setweight(to_tsvector('english'::regconfig, public.arr_text(keywords)), 'A') ||
    setweight(to_tsvector('english'::regconfig, coalesce(summary,'')), 'B') ||
    setweight(to_tsvector('english'::regconfig, coalesce(body,'') || ' ' || public.arr_text(symptoms) || ' ' || public.arr_text(causes) || ' ' || public.arr_text(prevention) || ' ' || coalesce(treatment_overview,'')), 'C')
  ) STORED
);

GRANT SELECT ON public.articles TO anon, authenticated;
GRANT ALL ON public.articles TO service_role;
ALTER TABLE public.articles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can read non-retired articles" ON public.articles
  FOR SELECT TO anon, authenticated USING (review_status <> 'retired');

CREATE INDEX articles_search_idx ON public.articles USING gin (search_vector);
CREATE INDEX articles_category_idx ON public.articles (category);
CREATE INDEX articles_keywords_idx ON public.articles USING gin (keywords);

CREATE OR REPLACE FUNCTION public.set_updated_at() RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;
CREATE TRIGGER articles_updated_at BEFORE UPDATE ON public.articles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.search_articles(q text, cat text DEFAULT NULL, max_results int DEFAULT 6)
RETURNS TABLE (id uuid, title text, slug text, category text, topic text, summary text, body text, source_name text, source_url text, last_reviewed_at date, review_status text, rank real)
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = public AS $$
DECLARE prefix_q tsquery;
BEGIN
  SELECT to_tsquery('english', string_agg(lexeme || ':*', ' | ')) INTO prefix_q FROM unnest(to_tsvector('english', left(q, 300)));
  IF prefix_q IS NULL THEN RETURN; END IF;
  RETURN QUERY
  SELECT a.id, a.title, a.slug, a.category, a.topic, a.summary, a.body, a.source_name, a.source_url, a.last_reviewed_at, a.review_status,
         ts_rank(a.search_vector, prefix_q) AS rank
  FROM public.articles a
  WHERE a.review_status <> 'retired'
    AND (cat IS NULL OR a.category = cat)
    AND a.search_vector @@ prefix_q
  ORDER BY rank DESC
  LIMIT least(greatest(max_results,1),10);
END; $$;
GRANT EXECUTE ON FUNCTION public.search_articles(text, text, int) TO anon, authenticated;

INSERT INTO public.articles (title, slug, category, topic, summary, body, symptoms, causes, prevention, treatment_overview, keywords, source_name, source_url) VALUES
('Common cold','common-cold','condition','Respiratory infections',
 'The common cold is a mild viral infection of the nose and throat. Most people recover on their own within about a week to ten days.',
 'Colds are caused by many different viruses, most often rhinoviruses. They spread through droplets in the air and by touching contaminated surfaces and then the face. There is no cure for the common cold; antibiotics do not work against viruses. Care focuses on rest, fluids and relief of symptoms. See a health professional if symptoms are severe, last longer than expected, or if there is difficulty breathing, high fever, or symptoms in a very young infant.',
 ARRAY['Runny or stuffy nose','Sneezing','Sore throat','Cough','Mild tiredness'], ARRAY['Viruses such as rhinoviruses','Close contact with infected people'], ARRAY['Wash hands often','Avoid touching eyes, nose and mouth','Stay away from people who are sick'],
 'No cure; rest, fluids and over-the-counter symptom relief may help. Antibiotics do not treat colds.',
 ARRAY['cold','runny nose','sneezing','sore throat','cough','virus'], 'MedlinePlus (U.S. National Library of Medicine)', 'https://medlineplus.gov/commoncold.html'),
('Influenza (flu)','influenza','condition','Respiratory infections',
 'Influenza is a contagious respiratory illness caused by influenza viruses. It can be mild to severe and can lead to complications in some groups.',
 'Flu often comes on suddenly. Older adults, young children, pregnant people and those with certain long-term conditions are at higher risk of complications. Annual vaccination is the main way to reduce risk. Antiviral medicines prescribed by a clinician may help some people. Seek urgent care for difficulty breathing, chest pain, confusion, or worsening symptoms.',
 ARRAY['Fever or feeling feverish','Cough','Sore throat','Muscle or body aches','Headache','Tiredness'], ARRAY['Influenza viruses spread by droplets'], ARRAY['Yearly flu vaccine','Hand washing','Staying home when sick'],
 'Rest and fluids; a clinician may prescribe antiviral medicine for some people.',
 ARRAY['flu','influenza','fever','body aches','cough','vaccine'], 'MedlinePlus (U.S. National Library of Medicine)', 'https://medlineplus.gov/flu.html'),
('Diabetes','diabetes','condition','Metabolic conditions',
 'Diabetes is a long-term condition in which blood glucose (sugar) levels are too high, either because the body does not make enough insulin or cannot use it well.',
 'The main types are type 1, type 2 and gestational diabetes. Over time, high blood glucose can damage the eyes, kidneys, nerves and heart. Diagnosis requires blood tests by a health professional. Management is individual and may include healthy eating, physical activity, monitoring and medicines such as insulin, decided with a clinician.',
 ARRAY['Increased thirst','Frequent urination','Unexplained weight loss','Tiredness','Blurred vision','Slow-healing sores'], ARRAY['Type 1: autoimmune loss of insulin-making cells','Type 2: insulin resistance; risk rises with excess weight, inactivity and family history'], ARRAY['Healthy weight','Regular physical activity','Balanced diet'],
 'Managed with a care team; may include lifestyle changes, glucose monitoring and medicines.',
 ARRAY['diabetes','blood sugar','glucose','insulin','thirst','urination'], 'MedlinePlus (U.S. National Library of Medicine)', 'https://medlineplus.gov/diabetes.html'),
('High blood pressure (hypertension)','hypertension','condition','Heart and circulation',
 'Hypertension means the force of blood against artery walls is consistently too high. It often has no symptoms, so regular checks matter.',
 'Untreated high blood pressure raises the risk of heart disease, stroke and kidney disease. It can only be confirmed by measuring blood pressure. Lifestyle changes and, when needed, medicines prescribed by a clinician can lower it. Very high readings with symptoms such as chest pain, severe headache, vision changes or weakness need emergency care.',
 ARRAY['Often no symptoms'], ARRAY['Older age','Family history','High salt intake','Excess weight','Physical inactivity','Alcohol and tobacco use'], ARRAY['Reduce salt','Stay active','Limit alcohol','Avoid tobacco','Regular blood pressure checks'],
 'Lifestyle changes and prescribed medicines; follow your clinician''s plan.',
 ARRAY['hypertension','blood pressure','bp','heart','stroke'], 'MedlinePlus (U.S. National Library of Medicine)', 'https://medlineplus.gov/highbloodpressure.html'),
('Asthma','asthma','condition','Respiratory conditions',
 'Asthma is a long-term condition in which the airways become inflamed and narrowed, making breathing harder at times.',
 'Asthma symptoms can be triggered by allergens, smoke, exercise, cold air or infections. An asthma action plan made with a clinician helps people know what to do. A severe attack — when a reliever inhaler does not help, or speaking and breathing are very difficult, or lips turn blue — is an emergency.',
 ARRAY['Wheezing','Shortness of breath','Chest tightness','Coughing, especially at night'], ARRAY['Airway inflammation','Triggers such as allergens, smoke and infections'], ARRAY['Know and avoid triggers','Follow an asthma action plan'],
 'Usually managed with inhaled medicines prescribed by a clinician.',
 ARRAY['asthma','wheezing','inhaler','breathless','shortness of breath'], 'MedlinePlus (U.S. National Library of Medicine)', 'https://medlineplus.gov/asthma.html'),
('Migraine','migraine','condition','Neurological conditions',
 'Migraine is a type of headache disorder that often causes throbbing pain, usually on one side, and may come with nausea and sensitivity to light or sound.',
 'Some people notice warning signs (aura) such as visual changes before an attack. Triggers vary. A sudden, extremely severe headache, headache with weakness, confusion, fever with stiff neck, or after a head injury needs urgent medical care because it may not be migraine.',
 ARRAY['Throbbing head pain','Nausea or vomiting','Sensitivity to light and sound','Aura in some people'], ARRAY['Exact cause not fully understood','Triggers may include stress, sleep changes, certain foods, hormones'], ARRAY['Identify triggers','Regular sleep and meals'],
 'Treatments for attacks and prevention exist; discuss options with a clinician.',
 ARRAY['migraine','headache','aura','nausea','light sensitivity'], 'MedlinePlus (U.S. National Library of Medicine)', 'https://medlineplus.gov/migraine.html'),
('Anaemia','anaemia','condition','Blood conditions',
 'Anaemia (anemia) means the blood has fewer healthy red blood cells or less haemoglobin than normal, which reduces oxygen delivery to the body.',
 'There are many types and causes, including iron deficiency, vitamin deficiencies, blood loss and chronic disease. Only a blood test can confirm anaemia and its cause. Treatment depends on the cause and should be guided by a clinician.',
 ARRAY['Tiredness','Weakness','Pale skin','Shortness of breath','Dizziness'], ARRAY['Low iron, vitamin B12 or folate','Blood loss','Chronic conditions','Inherited conditions'], ARRAY['Diet with iron-rich foods','Address underlying causes with a clinician'],
 'Depends on the cause; may include dietary changes or supplements recommended by a clinician.',
 ARRAY['anaemia','anemia','iron','fatigue','pale','haemoglobin'], 'MedlinePlus (U.S. National Library of Medicine)', 'https://medlineplus.gov/anemia.html'),
('Dehydration','dehydration','condition','General health',
 'Dehydration happens when the body loses more fluid than it takes in. It can be caused by heat, vomiting, diarrhoea, fever or not drinking enough.',
 'Infants, young children and older adults are at higher risk. Mild dehydration can often be managed by drinking fluids; oral rehydration solutions can help with diarrhoea. Seek urgent care for confusion, fainting, no urination, rapid heartbeat or signs of severe dehydration in a child.',
 ARRAY['Thirst','Dark urine or urinating less','Dry mouth','Tiredness','Dizziness'], ARRAY['Heat and sweating','Vomiting or diarrhoea','Fever','Low fluid intake'], ARRAY['Drink fluids regularly, more in heat or illness'],
 'Replace fluids; severe cases may need medical treatment.',
 ARRAY['dehydration','thirst','fluids','heat','diarrhoea','diarrhea'], 'MedlinePlus (U.S. National Library of Medicine)', 'https://medlineplus.gov/dehydration.html'),
('Allergies','allergies','condition','Immune system',
 'An allergy is a reaction of the immune system to a substance that is usually harmless, such as pollen, dust mites, foods or insect stings.',
 'Reactions range from mild (sneezing, itchy eyes, rash) to severe. Anaphylaxis — with trouble breathing, throat swelling, faintness — is a medical emergency needing immediate help. A clinician can help identify allergens and plan management.',
 ARRAY['Sneezing','Itchy or watery eyes','Rash or hives','Swelling'], ARRAY['Pollen','Dust mites','Animal dander','Certain foods','Insect stings','Some medicines'], ARRAY['Avoid known triggers'],
 'Avoiding triggers and medicines recommended by a clinician; emergency treatment for anaphylaxis.',
 ARRAY['allergy','allergies','hay fever','hives','anaphylaxis','pollen'], 'MedlinePlus (U.S. National Library of Medicine)', 'https://medlineplus.gov/allergy.html'),
('Dengue','dengue','condition','Infectious diseases',
 'Dengue is a viral infection spread to people through the bite of infected Aedes mosquitoes, common in tropical and subtropical regions.',
 'Many infections cause mild or no symptoms, but some people develop severe dengue, which can be life-threatening. Warning signs include severe abdominal pain, persistent vomiting, bleeding gums or nose, rapid breathing, tiredness or restlessness — these need urgent medical care. There is no specific antiviral treatment; care is supportive under medical guidance.',
 ARRAY['High fever','Severe headache','Pain behind the eyes','Muscle and joint pains','Nausea and vomiting','Rash'], ARRAY['Bite of infected Aedes mosquitoes'], ARRAY['Prevent mosquito bites','Remove standing water where mosquitoes breed'],
 'Supportive care under medical supervision; seek care early for warning signs.',
 ARRAY['dengue','mosquito','fever','rash','joint pain','tropical'], 'World Health Organization', 'https://www.who.int/news-room/fact-sheets/detail/dengue-and-severe-dengue'),
('Acetaminophen (paracetamol)','acetaminophen','medication','Pain relief',
 'Acetaminophen, also called paracetamol, is a commonly used medicine for mild to moderate pain and fever.',
 'Taking more than the recommended amount, or combining several products that contain acetaminophen, can cause serious liver damage. People who drink alcohol regularly or have liver disease should talk to a clinician or pharmacist before use. Always follow the product label or your clinician''s instructions; this app does not provide personal dosing.',
 '{}', '{}', '{}', NULL,
 ARRAY['acetaminophen','paracetamol','tylenol','pain','fever','liver'], 'MedlinePlus Drug Information', 'https://medlineplus.gov/druginfo/meds/a681004.html'),
('Ibuprofen','ibuprofen','medication','Pain relief',
 'Ibuprofen is a nonsteroidal anti-inflammatory drug (NSAID) used to relieve pain, fever and inflammation.',
 'NSAIDs can increase the risk of stomach bleeding and of heart attack or stroke, especially with long-term use or in people with certain conditions. They may interact with other medicines such as blood thinners. Ask a pharmacist or clinician before use if you have heart, kidney or stomach problems, are pregnant, or take other medicines. Follow the label; this app does not provide personal dosing.',
 '{}', '{}', '{}', NULL,
 ARRAY['ibuprofen','nsaid','advil','pain','inflammation','fever'], 'MedlinePlus Drug Information', 'https://medlineplus.gov/druginfo/meds/a682159.html'),
('Physical activity','physical-activity','wellness','Fitness',
 'Regular physical activity benefits heart health, mood, sleep and overall wellbeing, and helps prevent several long-term conditions.',
 'WHO provides general recommendations for weekly aerobic activity and muscle-strengthening for different age groups. Some activity is better than none, and reducing sedentary time helps. People with health conditions should check with a clinician before starting a new exercise programme.',
 '{}', '{}', ARRAY['Move more, sit less','Combine aerobic and strength activities'], NULL,
 ARRAY['exercise','fitness','physical activity','workout','sedentary'], 'World Health Organization', 'https://www.who.int/news-room/fact-sheets/detail/physical-activity'),
('Healthy diet','healthy-diet','wellness','Nutrition',
 'A healthy diet helps protect against malnutrition and many noncommunicable diseases such as diabetes, heart disease and stroke.',
 'General principles include eating plenty of fruits, vegetables, legumes and whole grains, and limiting free sugars, salt and unhealthy fats. Individual needs vary; people with medical conditions should seek personalised advice from a clinician or registered dietitian.',
 '{}', '{}', ARRAY['Eat a variety of fruits and vegetables','Limit salt, sugar and unhealthy fats'], NULL,
 ARRAY['nutrition','diet','food','healthy eating','salt','sugar'], 'World Health Organization', 'https://www.who.int/news-room/fact-sheets/detail/healthy-diet');

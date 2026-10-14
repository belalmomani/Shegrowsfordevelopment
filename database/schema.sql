-- =====================================================================
-- She Grows for Development - Database Schema (Phase 1 design draft)
-- Target: MySQL 8 / MariaDB 10.4+  |  Engine: InnoDB  |  utf8mb4
-- لا يحتوي على أي بيانات أشخاص أو مستخدمين. المستخدم الأول يُنشأ
-- عبر سكربت التثبيت في المرحلة الثانية (بلا كلمة مرور افتراضية).
-- =====================================================================
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------- 1. المرجعيات ----------
CREATE TABLE governorates (
  id TINYINT UNSIGNED PRIMARY KEY,
  name_ar VARCHAR(50) NOT NULL,
  name_en VARCHAR(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE thematic_areas (
  id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name_ar VARCHAR(100) NOT NULL,
  name_en VARCHAR(100) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------- 2. المستخدمون والأدوار والصلاحيات ----------
CREATE TABLE roles (
  id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(40) NOT NULL UNIQUE,
  name_ar VARCHAR(80) NOT NULL,
  name_en VARCHAR(80) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE permissions (
  id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(60) NOT NULL UNIQUE,
  description VARCHAR(200) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE role_permissions (
  role_id SMALLINT UNSIGNED NOT NULL,
  permission_id SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (role_id, permission_id),
  FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
  FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(190) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  full_name VARCHAR(150) NOT NULL,
  lang CHAR(2) NOT NULL DEFAULT 'ar',
  status ENUM('active','suspended','pending') NOT NULL DEFAULT 'pending',
  last_login_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE user_roles (
  user_id INT UNSIGNED NOT NULL,
  role_id SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, role_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE login_attempts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  identifier_hash CHAR(64) NOT NULL,
  ip_hash CHAR(64) NOT NULL,
  success TINYINT(1) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_login_lookup (identifier_hash, created_at),
  KEY idx_login_ip (ip_hash, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE password_resets (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  used_at DATETIME NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  KEY idx_reset_token (token_hash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------- 3. الأعضاء / المستفيدات / المتطوعات ----------
-- members = هوية الشخص الواحد (لمنع التكرار). قد لا يملك حساب دخول.
CREATE TABLE members (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NULL UNIQUE,
  full_name VARCHAR(150) NOT NULL,
  phone VARCHAR(30) NULL,
  email VARCHAR(190) NULL,
  phone_norm VARCHAR(20) NULL,           -- رقم مطبّع للكشف عن التكرار
  email_norm VARCHAR(190) NULL,
  governorate_id TINYINT UNSIGNED NULL,
  birth_year SMALLINT UNSIGNED NULL,     -- سنة الميلاد فقط (تقليل البيانات)
  specialization VARCHAR(150) NULL,
  interests VARCHAR(300) NULL,
  member_types SET('member','beneficiary','volunteer','expert','partner_contact') NOT NULL DEFAULT 'beneficiary',
  membership_status ENUM('active','inactive','alumni','suspended') NOT NULL DEFAULT 'active',
  merged_into_id INT UNSIGNED NULL,      -- عند دمج سجلين مكررين
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at DATETIME NULL,              -- إخفاء/إخفاء هوية وفق سياسة الاحتفاظ
  UNIQUE KEY uq_member_phone (phone_norm),
  UNIQUE KEY uq_member_email (email_norm),
  KEY idx_member_gov (governorate_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (governorate_id) REFERENCES governorates(id),
  FOREIGN KEY (merged_into_id) REFERENCES members(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- موافقات البيانات (ومنها موافقة ولي الأمر للقاصرين، مثل برنامج EPICC)
CREATE TABLE member_consents (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  member_id INT UNSIGNED NOT NULL,
  consent_type ENUM('data_processing','guardian_consent','media_use','contact') NOT NULL,
  policy_version VARCHAR(20) NOT NULL,
  granted_at DATETIME NOT NULL,
  withdrawn_at DATETIME NULL,
  guardian_name VARCHAR(150) NULL,
  guardian_phone VARCHAR(30) NULL,
  recorded_by INT UNSIGNED NULL,
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
  FOREIGN KEY (recorded_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE member_achievements (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  member_id INT UNSIGNED NOT NULL,
  title VARCHAR(200) NOT NULL,
  description TEXT NULL,
  achieved_on DATE NULL,
  verification_status ENUM('pending','verified','rejected') NOT NULL DEFAULT 'pending',
  verified_by INT UNSIGNED NULL,
  verified_at DATETIME NULL,
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
  FOREIGN KEY (verified_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE partners (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name_ar VARCHAR(150) NOT NULL,
  name_en VARCHAR(150) NULL,
  partner_type ENUM('funder','implementing','academic','government','private','other') NOT NULL DEFAULT 'other',
  website VARCHAR(255) NULL,
  notes TEXT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------- 4. البرامج والدورات ----------
-- programs = عائلة البرنامج (مثل SGN, EPICC, CJP)
-- program_cycles = النسخة/الدفعة القابلة للتنفيذ (لها تواريخ ومقاعد وحالة)
CREATE TABLE programs (
  id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  slug VARCHAR(40) NOT NULL UNIQUE,
  name_ar VARCHAR(150) NOT NULL,
  name_en VARCHAR(150) NOT NULL,
  description_ar TEXT NULL,
  description_en TEXT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE program_cycles (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  program_id SMALLINT UNSIGNED NOT NULL,
  title_ar VARCHAR(200) NOT NULL,
  title_en VARCHAR(200) NULL,
  description_ar TEXT NULL,
  description_en TEXT NULL,
  objectives TEXT NULL,
  target_group VARCHAR(300) NULL,
  thematic_area_id SMALLINT UNSIGNED NULL,
  governorate_id TINYINT UNSIGNED NULL,
  start_date DATE NULL,
  end_date DATE NULL,
  eligibility TEXT NULL,
  seats SMALLINT UNSIGNED NULL,
  min_attendance_pct TINYINT UNSIGNED NOT NULL DEFAULT 75,  -- شرط الإكمال (قابل للتعديل)
  status ENUM('draft','published','registration_open','registration_closed','in_progress','completed','archived') NOT NULL DEFAULT 'draft',
  is_public TINYINT(1) NOT NULL DEFAULT 0,
  created_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_cycle_status (status),
  FOREIGN KEY (program_id) REFERENCES programs(id),
  FOREIGN KEY (thematic_area_id) REFERENCES thematic_areas(id),
  FOREIGN KEY (governorate_id) REFERENCES governorates(id),
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- فريق الدورة + نطاق صلاحية المنسقة/المدققة
CREATE TABLE cycle_team (
  cycle_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  team_role ENUM('coordinator','impact_officer','trainer','donor_viewer','other') NOT NULL,
  PRIMARY KEY (cycle_id, user_id, team_role),
  FOREIGN KEY (cycle_id) REFERENCES program_cycles(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cycle_partners (
  cycle_id INT UNSIGNED NOT NULL,
  partner_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (cycle_id, partner_id),
  FOREIGN KEY (cycle_id) REFERENCES program_cycles(id) ON DELETE CASCADE,
  FOREIGN KEY (partner_id) REFERENCES partners(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cycle_attachments (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cycle_id INT UNSIGNED NOT NULL,
  kind ENUM('file','link') NOT NULL,
  title VARCHAR(200) NOT NULL,
  url_or_path VARCHAR(500) NOT NULL,
  mime_type VARCHAR(100) NULL,
  size_bytes INT UNSIGNED NULL,
  sha256 CHAR(64) NULL,
  is_public TINYINT(1) NOT NULL DEFAULT 0,
  uploaded_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (cycle_id) REFERENCES program_cycles(id) ON DELETE CASCADE,
  FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cycle_budget_lines (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cycle_id INT UNSIGNED NOT NULL,
  category VARCHAR(100) NOT NULL,
  planned_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  actual_amount DECIMAL(12,2) NULL,
  currency CHAR(3) NOT NULL DEFAULT 'JOD',
  notes VARCHAR(300) NULL,
  FOREIGN KEY (cycle_id) REFERENCES program_cycles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cycle_reports (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cycle_id INT UNSIGNED NOT NULL,
  report_type ENUM('progress','closure') NOT NULL,
  body TEXT NOT NULL,
  created_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (cycle_id) REFERENCES program_cycles(id) ON DELETE CASCADE,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------- 5. نموذج التسجيل والطلبات ----------
CREATE TABLE cycle_form_fields (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cycle_id INT UNSIGNED NOT NULL,
  field_key VARCHAR(50) NOT NULL,
  label_ar VARCHAR(200) NOT NULL,
  label_en VARCHAR(200) NULL,
  field_type ENUM('text','textarea','number','select','multiselect','date','checkbox','file') NOT NULL,
  options_json TEXT NULL,
  is_required TINYINT(1) NOT NULL DEFAULT 0,
  sort_order SMALLINT NOT NULL DEFAULT 0,
  UNIQUE KEY uq_cycle_field (cycle_id, field_key),
  FOREIGN KEY (cycle_id) REFERENCES program_cycles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE applications (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  reference_no VARCHAR(20) NOT NULL UNIQUE,
  cycle_id INT UNSIGNED NOT NULL,
  member_id INT UNSIGNED NOT NULL,
  status ENUM('new','under_review','accepted','waitlist','rejected','withdrawn') NOT NULL DEFAULT 'new',
  answers_json LONGTEXT NULL,
  submitted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  decided_by INT UNSIGNED NULL,
  decided_at DATETIME NULL,
  UNIQUE KEY uq_one_app_per_member_cycle (cycle_id, member_id),
  KEY idx_app_status (cycle_id, status),
  FOREIGN KEY (cycle_id) REFERENCES program_cycles(id),
  FOREIGN KEY (member_id) REFERENCES members(id),
  FOREIGN KEY (decided_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE application_status_history (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  application_id INT UNSIGNED NOT NULL,
  from_status VARCHAR(20) NULL,
  to_status VARCHAR(20) NOT NULL,
  changed_by INT UNSIGNED NULL,
  changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE CASCADE,
  FOREIGN KEY (changed_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ملاحظات داخلية: لا تُعرض للمستفيدة أبدا
CREATE TABLE application_notes (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  application_id INT UNSIGNED NOT NULL,
  note TEXT NOT NULL,
  created_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE CASCADE,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------- 6. المشاركة والحضور والتقييم ----------
-- التسجيل (applications) ≠ المشاركة (participations) ≠ الحضور ≠ الإكمال
CREATE TABLE participations (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cycle_id INT UNSIGNED NOT NULL,
  member_id INT UNSIGNED NOT NULL,
  application_id INT UNSIGNED NULL,
  status ENUM('enrolled','withdrawn','completed','not_completed') NOT NULL DEFAULT 'enrolled',
  completed_at DATETIME NULL,
  completion_decided_by INT UNSIGNED NULL,
  UNIQUE KEY uq_participation (cycle_id, member_id),
  FOREIGN KEY (cycle_id) REFERENCES program_cycles(id),
  FOREIGN KEY (member_id) REFERENCES members(id),
  FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE SET NULL,
  FOREIGN KEY (completion_decided_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cycle_sessions (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cycle_id INT UNSIGNED NOT NULL,
  title VARCHAR(200) NOT NULL,
  session_date DATE NOT NULL,
  location VARCHAR(200) NULL,
  FOREIGN KEY (cycle_id) REFERENCES program_cycles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE attendance (
  session_id INT UNSIGNED NOT NULL,
  participation_id INT UNSIGNED NOT NULL,
  status ENUM('present','absent','excused','late') NOT NULL,
  recorded_by INT UNSIGNED NULL,
  recorded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (session_id, participation_id),
  FOREIGN KEY (session_id) REFERENCES cycle_sessions(id) ON DELETE CASCADE,
  FOREIGN KEY (participation_id) REFERENCES participations(id) ON DELETE CASCADE,
  FOREIGN KEY (recorded_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE assessments (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cycle_id INT UNSIGNED NOT NULL,
  kind ENUM('pre','post','other') NOT NULL,
  title VARCHAR(200) NOT NULL,
  pair_key VARCHAR(40) NULL,           -- يربط اختبارا قبليا بآخر بعدي لمقارنتهما
  FOREIGN KEY (cycle_id) REFERENCES program_cycles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE assessment_questions (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  assessment_id INT UNSIGNED NOT NULL,
  question_key VARCHAR(40) NOT NULL,   -- نفس المفتاح في القبلي والبعدي لضمان المقارنة
  text_ar VARCHAR(500) NOT NULL,
  text_en VARCHAR(500) NULL,
  q_type ENUM('scale','choice','number','text') NOT NULL,
  options_json TEXT NULL,
  max_score DECIMAL(6,2) NULL,
  sort_order SMALLINT NOT NULL DEFAULT 0,
  FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE assessment_responses (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  assessment_id INT UNSIGNED NOT NULL,
  participation_id INT UNSIGNED NOT NULL,
  total_score DECIMAL(8,2) NULL,
  submitted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_response (assessment_id, participation_id),
  FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE CASCADE,
  FOREIGN KEY (participation_id) REFERENCES participations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE assessment_answers (
  response_id INT UNSIGNED NOT NULL,
  question_id INT UNSIGNED NOT NULL,
  value_text VARCHAR(1000) NULL,
  value_num DECIMAL(10,2) NULL,
  PRIMARY KEY (response_id, question_id),
  FOREIGN KEY (response_id) REFERENCES assessment_responses(id) ON DELETE CASCADE,
  FOREIGN KEY (question_id) REFERENCES assessment_questions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------- 7. التطوع والفرص ----------
CREATE TABLE opportunities (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cycle_id INT UNSIGNED NULL,
  title_ar VARCHAR(200) NOT NULL,
  title_en VARCHAR(200) NULL,
  description TEXT NULL,
  opp_type ENUM('volunteering','expert','event','other') NOT NULL DEFAULT 'volunteering',
  seats SMALLINT UNSIGNED NULL,
  status ENUM('draft','open','closed','archived') NOT NULL DEFAULT 'draft',
  created_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (cycle_id) REFERENCES program_cycles(id) ON DELETE SET NULL,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE opportunity_signups (
  opportunity_id INT UNSIGNED NOT NULL,
  member_id INT UNSIGNED NOT NULL,
  status ENUM('applied','accepted','declined','withdrawn') NOT NULL DEFAULT 'applied',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (opportunity_id, member_id),
  FOREIGN KEY (opportunity_id) REFERENCES opportunities(id) ON DELETE CASCADE,
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE volunteer_hours (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  member_id INT UNSIGNED NOT NULL,
  opportunity_id INT UNSIGNED NULL,
  work_date DATE NOT NULL,
  hours DECIMAL(5,2) NOT NULL,
  description VARCHAR(300) NULL,
  verification_status ENUM('pending','verified','rejected') NOT NULL DEFAULT 'pending',
  verified_by INT UNSIGNED NULL,
  verified_at DATETIME NULL,
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
  FOREIGN KEY (opportunity_id) REFERENCES opportunities(id) ON DELETE SET NULL,
  FOREIGN KEY (verified_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------- 8. قياس الأثر ----------
CREATE TABLE indicators (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(40) NOT NULL UNIQUE,
  name_ar VARCHAR(200) NOT NULL,
  name_en VARCHAR(200) NULL,
  definition TEXT NOT NULL,
  level ENUM('input_activity','output','outcome','long_term_impact') NOT NULL,
  program_id SMALLINT UNSIGNED NULL,
  cycle_id INT UNSIGNED NULL,
  unit VARCHAR(50) NOT NULL,
  baseline_value DECIMAL(14,2) NULL,
  target_value DECIMAL(14,2) NULL,
  calc_method ENUM('manual','auto_unique_participants','auto_completion_rate','auto_prepost_change') NOT NULL DEFAULT 'manual',
  data_source VARCHAR(300) NULL,
  responsible_user_id INT UNSIGNED NULL,
  approval_status ENUM('draft','proposed','approved','retired') NOT NULL DEFAULT 'draft',
  approved_by INT UNSIGNED NULL,
  approved_at DATETIME NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (program_id) REFERENCES programs(id) ON DELETE SET NULL,
  FOREIGN KEY (cycle_id) REFERENCES program_cycles(id) ON DELETE SET NULL,
  FOREIGN KEY (responsible_user_id) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- القيمة الفعلية والتقديرية تُسجل هنا، منفصلة عن الهدف في جدول المؤشرات
CREATE TABLE indicator_measurements (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  indicator_id INT UNSIGNED NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  value DECIMAL(14,2) NOT NULL,
  value_type ENUM('actual','estimated') NOT NULL DEFAULT 'actual',
  source_note VARCHAR(500) NULL,
  entered_by INT UNSIGNED NULL,
  verification_status ENUM('pending','verified','rejected','needs_info') NOT NULL DEFAULT 'pending',
  verified_by INT UNSIGNED NULL,
  verified_at DATETIME NULL,
  review_notes TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_meas_ind (indicator_id, period_end),
  FOREIGN KEY (indicator_id) REFERENCES indicators(id) ON DELETE CASCADE,
  FOREIGN KEY (entered_by) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (verified_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE evidence_files (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  measurement_id INT UNSIGNED NOT NULL,
  kind ENUM('file','link') NOT NULL,
  title VARCHAR(200) NOT NULL,
  url_or_path VARCHAR(500) NOT NULL,
  mime_type VARCHAR(100) NULL,
  size_bytes INT UNSIGNED NULL,
  sha256 CHAR(64) NULL,
  uploaded_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (measurement_id) REFERENCES indicator_measurements(id) ON DELETE CASCADE,
  FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------- 9. الإشعارات والتدقيق والخصوصية ----------
CREATE TABLE notifications (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  type VARCHAR(40) NOT NULL,
  title VARCHAR(200) NOT NULL,
  body VARCHAR(500) NULL,
  related_type VARCHAR(40) NULL,
  related_id INT UNSIGNED NULL,
  read_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_notif_user (user_id, read_at),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- سجل التدقيق: يخزّن أسماء الحقول المتغيرة والمعرّفات، لا القيم الشخصية
CREATE TABLE audit_log (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NULL,
  action VARCHAR(60) NOT NULL,
  entity_type VARCHAR(40) NOT NULL,
  entity_id INT UNSIGNED NULL,
  changed_fields VARCHAR(500) NULL,
  ip_hash CHAR(64) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_audit_entity (entity_type, entity_id),
  KEY idx_audit_user (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE data_requests (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  member_id INT UNSIGNED NOT NULL,
  request_type ENUM('correction','deletion','export') NOT NULL,
  details TEXT NULL,
  status ENUM('open','in_progress','done','rejected') NOT NULL DEFAULT 'open',
  handled_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  closed_at DATETIME NULL,
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
  FOREIGN KEY (handled_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE report_exports (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NULL,
  report_code VARCHAR(60) NOT NULL,
  format ENUM('csv','xlsx','pdf') NOT NULL,
  includes_personal_data TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE settings (
  setting_key VARCHAR(60) PRIMARY KEY,
  setting_value TEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- بيانات مرجعية أساسية (ليست بيانات تجريبية)
-- =====================================================================
INSERT INTO governorates (id, name_ar, name_en) VALUES
 (1,'عمّان','Amman'),(2,'إربد','Irbid'),(3,'الزرقاء','Zarqa'),(4,'البلقاء','Balqa'),
 (5,'المفرق','Mafraq'),(6,'جرش','Jerash'),(7,'عجلون','Ajloun'),(8,'الكرك','Karak'),
 (9,'الطفيلة','Tafilah'),(10,'معان','Ma''an'),(11,'العقبة','Aqaba'),(12,'مأدبا','Madaba');

-- المجالات كما وردت في الموقع المنشور؛ قابلة للتعديل من لوحة الإدارة
INSERT INTO thematic_areas (name_ar, name_en) VALUES
 ('الاستدامة البيئية','Environmental sustainability'),
 ('العمل المناخي','Climate action'),
 ('ترابط المياه والطاقة والغذاء','Water-Energy-Food Nexus'),
 ('التعليم المناخي','Climate education'),
 ('الصحافة المناخية','Climate journalism');

-- البرامج الثلاثة المنشورة فعليا على الموقع
INSERT INTO programs (slug, name_ar, name_en) VALUES
 ('sgn','شبكة هي تزرع','She Grows Network (SGN)'),
 ('epicc','البرنامج التعليمي للتغير المناخي','Educational Program in Climate Change (EPICC)'),
 ('cjp','برنامج الصحافة المناخية','Climate Journalism Program (CJP)');

INSERT INTO roles (code, name_ar, name_en) VALUES
 ('system_admin','مدير النظام','System Admin'),
 ('org_management','إدارة المؤسسة','Organization Management'),
 ('program_coordinator','منسقة البرنامج','Program Coordinator'),
 ('impact_officer','مسؤولة قياس الأثر','Impact Officer'),
 ('auditor_donor','المدققة / المانحة','Auditor / Donor'),
 ('member','العضوة / المستفيدة','Member / Beneficiary'),
 ('volunteer_expert','المتطوعة / الخبيرة','Volunteer / Expert');

INSERT INTO permissions (code, description) VALUES
 ('users.manage','إدارة المستخدمين والأدوار'),
 ('settings.manage','إدارة إعدادات النظام'),
 ('audit.view','عرض سجل التدقيق'),
 ('programs.view_all','عرض كل البرامج والدورات'),
 ('programs.manage','إنشاء وتعديل ونشر وأرشفة الدورات'),
 ('programs.manage_assigned','إدارة الدورات المسندة فقط'),
 ('applications.view_assigned','عرض طلبات الدورات المسندة'),
 ('applications.decide_assigned','تغيير حالة الطلبات في الدورات المسندة'),
 ('applications.view_all','عرض كل الطلبات'),
 ('members.view_assigned','عرض مشاركات الدورات المسندة'),
 ('members.view_all','عرض كل الأعضاء'),
 ('members.manage','تعديل ودمج وحذف سجلات الأعضاء'),
 ('attendance.record_assigned','تسجيل الحضور والإكمال في الدورات المسندة'),
 ('assessments.manage_assigned','إدارة التقييمات في الدورات المسندة'),
 ('indicators.define','تعريف المؤشرات'),
 ('indicators.enter','إدخال قيم المؤشرات'),
 ('indicators.verify','التحقق من النتائج واعتمادها'),
 ('indicators.approve','اعتماد المؤشرات رسميا'),
 ('reports.view_aggregate','عرض التقارير المجمّعة'),
 ('reports.view_personal','عرض تقارير فيها بيانات شخصية'),
 ('reports.export','تصدير التقارير'),
 ('opportunities.manage','إدارة فرص التطوع والمشاركة'),
 ('volunteer_hours.verify','اعتماد ساعات التطوع'),
 ('data_requests.handle','معالجة طلبات التصحيح والحذف'),
 ('self.profile','إدارة الملف الشخصي الذاتي'),
 ('self.applications','تقديم ومتابعة طلباتي'),
 ('self.opportunities','التسجيل في الفرص وتسجيل ساعاتي');

-- ربط الأدوار بالصلاحيات (الافتراضي الأقل صلاحية؛ التعديل من لوحة الإدارة)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON
 (r.code='system_admin' AND p.code IN ('users.manage','settings.manage','audit.view','data_requests.handle'))
 OR (r.code='org_management' AND p.code IN ('programs.view_all','programs.manage','applications.view_all','members.view_all','members.manage','indicators.approve','reports.view_aggregate','reports.view_personal','reports.export','opportunities.manage','audit.view','data_requests.handle'))
 OR (r.code='program_coordinator' AND p.code IN ('programs.manage_assigned','applications.view_assigned','applications.decide_assigned','members.view_assigned','attendance.record_assigned','assessments.manage_assigned','indicators.enter','opportunities.manage','volunteer_hours.verify','reports.view_aggregate','reports.export'))
 OR (r.code='impact_officer' AND p.code IN ('programs.view_all','indicators.define','indicators.enter','indicators.verify','reports.view_aggregate','reports.export'))
 OR (r.code='auditor_donor' AND p.code IN ('reports.view_aggregate'))
 OR (r.code='member' AND p.code IN ('self.profile','self.applications','self.opportunities'))
 OR (r.code='volunteer_expert' AND p.code IN ('self.profile','self.applications','self.opportunities'));

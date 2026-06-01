-- OLAI データベーススキーマ v2.1
-- PostgreSQL (Supabase) 用

-- 会社マスタ
CREATE TABLE companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  industry TEXT,
  address TEXT,
  phone TEXT,
  tax_type TEXT,          -- 'taxable'|'exempt'|'invoice'
  closing_day INT,        -- 締め日（末日=31）
  payment_terms TEXT,      -- 'next_month_end'など
  line_user_id TEXT,
  stamp_image_url TEXT,   -- 社印PNG（透過）
  logo_image_url TEXT,
  pdf_template_json JSONB, -- 書類レイアウト情報
  source_pdf_url TEXT,    -- 元PDFの保存先
  plan_type TEXT,         -- 'free'|'worker'|'business'
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 職人マスタ
CREATE TABLE workers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  line_user_id TEXT UNIQUE,
  bank_name TEXT,
  bank_branch TEXT,
  account_number TEXT,
  is_boss BOOLEAN DEFAULT false, -- 社長兼職人フラグ
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 単価マスタ（職人×現場×元請けで異なる単価に対応）
CREATE TABLE worker_unit_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id UUID REFERENCES workers(id) ON DELETE CASCADE,
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  site_id UUID REFERENCES sites(id) ON DELETE SET NULL, -- NULL=デフォルト単価
  client_id UUID REFERENCES clients(id) ON DELETE SET NULL, -- NULL=全元請け共通
  unit_type TEXT NOT NULL, -- 'room'|'sqm'|'daily'|'hourly'|'unit'|'fixed'
  unit_price INT NOT NULL,
  valid_from DATE NOT NULL,
  valid_to DATE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 元請けマスタ
CREATE TABLE clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  contact_name TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  bank_name TEXT,
  account_number TEXT,
  closing_day INT,
  payment_terms TEXT,
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 現場マスタ
CREATE TABLE sites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  room_format TEXT,       -- 'A-B-C'|'101-102-103'|'custom'
  total_rooms INT,
  line_group_id TEXT,
  status TEXT DEFAULT 'active', -- 'active'|'completed'
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 完了記録
CREATE TABLE completions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id UUID REFERENCES sites(id) ON DELETE CASCADE,
  worker_id UUID REFERENCES workers(id) ON DELETE CASCADE,
  room_number TEXT,
  quantity DECIMAL,        -- 部屋数・㎡・時間・個数
  unit_type TEXT,         -- 'room'|'sqm'|'daily'|'hourly'|'unit'|'fixed'
  unit_price INT,
  completed_at TIMESTAMP DEFAULT NOW()
);

-- ユーザー特典管理（無料化・割引）
CREATE TABLE user_benefits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  benefit_type TEXT,      -- 'free'|'discount'|'feature_unlock'
  discount_rate INT,      -- 割引率（100=無料）
  feature_key TEXT,      -- 特定機能のみ解放
  start_date DATE,
  end_date DATE,         -- NULLなら無期限
  reason TEXT,
  created_by TEXT,       -- 操作した管理者
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 請求書送付ログ
CREATE TABLE invoice_deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE,
  worker_id UUID REFERENCES workers(id) ON DELETE CASCADE,
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  sent_via_line BOOLEAN DEFAULT true,
  sent_via_email BOOLEAN DEFAULT true,
  email_address TEXT,
  sent_at TIMESTAMP DEFAULT NOW(),
  opened_at TIMESTAMP    -- メール開封検知（将来）
);

-- 請求書マスタ
CREATE TABLE invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
  worker_id UUID REFERENCES workers(id) ON DELETE SET NULL, -- 職人発行の場合
  invoice_type TEXT,     -- 'estimate'|'invoice'|'receipt'
  amount INT,
  tax_amount INT,
  total_amount INT,
  due_date DATE,
  status TEXT DEFAULT 'draft', -- 'draft'|'sent'|'paid'|'overdue'
  pdf_url TEXT,
  period_from DATE,
  period_to DATE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 仕訳テーブル
CREATE TABLE journal_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  description TEXT,
  amount INT,
  tax_amount INT,
  account_type TEXT,     -- '材料費'|'外注費'|'交通費'など
  receipt_image TEXT,    -- 領収書画像URL
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 管理者操作ログ
CREATE TABLE admin_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_name TEXT,
  action TEXT,
  target_company UUID REFERENCES companies(id),
  detail TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- インデックス作成
CREATE INDEX idx_companies_line_user_id ON companies(line_user_id);
CREATE INDEX idx_workers_company_id ON workers(company_id);
CREATE INDEX idx_workers_line_user_id ON workers(line_user_id);
CREATE INDEX idx_worker_unit_prices_worker_id ON worker_unit_prices(worker_id);
CREATE INDEX idx_worker_unit_prices_site_id ON worker_unit_prices(site_id);
CREATE INDEX idx_worker_unit_prices_client_id ON worker_unit_prices(client_id);
CREATE INDEX idx_clients_company_id ON clients(company_id);
CREATE INDEX idx_sites_company_id ON sites(company_id);
CREATE INDEX idx_completions_site_id ON completions(site_id);
CREATE INDEX idx_completions_worker_id ON completions(worker_id);
CREATE INDEX idx_invoices_company_id ON invoices(company_id);
CREATE INDEX idx_invoices_client_id ON invoices(client_id);
CREATE INDEX idx_journal_entries_company_id ON journal_entries(company_id);
CREATE INDEX idx_admin_logs_target_company ON admin_logs(target_company);

-- 更新トリガー関数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- 各テーブルに更新トリガーを追加
CREATE TRIGGER update_companies_updated_at BEFORE UPDATE ON companies FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_workers_updated_at BEFORE UPDATE ON workers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_worker_unit_prices_updated_at BEFORE UPDATE ON worker_unit_prices FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_clients_updated_at BEFORE UPDATE ON clients FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sites_updated_at BEFORE UPDATE ON sites FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_journal_entries_updated_at BEFORE UPDATE ON journal_entries FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_admin_logs_updated_at BEFORE UPDATE ON admin_logs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
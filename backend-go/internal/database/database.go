package database

import (
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"dental-crm-api/internal/core/domain"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

func maskDSN(dsn string) string {
	if len(dsn) < 10 {
		return "***"
	}
	if idx := strings.Index(dsn, "@"); idx != -1 {
		if protoIdx := strings.Index(dsn, "://"); protoIdx != -1 {
			return dsn[:protoIdx+3] + "***" + dsn[idx:]
		}
	}
	return dsn
}

func cleanDSN(dsn string) string {
	dsn = strings.TrimSpace(dsn)
	dsn = strings.Trim(dsn, "\"'\r\n\t`")
	dsn = strings.ReplaceAll(dsn, "\r", "")
	dsn = strings.ReplaceAll(dsn, "\n", "")
	return dsn
}

func Connect() {
	dsn := os.Getenv("DATABASE_URL")
	dsn = cleanDSN(dsn)
	if dsn == "" {
		log.Fatal("❌ DATABASE_URL não está configurada nas variáveis de ambiente.")
	}

	log.Printf("🔌 Conectando ao banco de dados: %s", maskDSN(dsn))

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info), // Mostra as queries no console
	})
	if err != nil {
		log.Fatalf("❌ Falha ao conectar ao banco de dados Supabase: %v", err)
	}
	if db == nil {
		log.Fatal("❌ Instância de banco de dados retornou nil")
	}

	sqlDB, err := db.DB()
	if err != nil {
		log.Fatalf("❌ Falha ao obter SQL DB do GORM: %v", err)
	}

	if err := sqlDB.Ping(); err != nil {
		log.Fatalf("❌ Falha ao realizar ping no banco de dados Supabase: %v", err)
	}

	log.Println("✅ Conectado com sucesso ao Supabase via GORM!")
	DB = db

	RunMigrations()
}

func RunMigrations() {
	log.Println("Rodando AutoMigrate...")

	// O GORM criará as tabelas/colunas faltantes no Supabase automaticamente
	err := DB.AutoMigrate(
		&domain.Clinic{},
		&domain.Role{},
		&domain.User{},
		&domain.Patient{},
		&domain.Room{},
		&domain.Setting{},
		&domain.AppointmentType{},
		&domain.Waitlist{},
		&domain.ClinicalEvolution{},
		&domain.ClinicalNote{},
		&domain.MedicalDocument{},
		&domain.TeethStatus{},
		&domain.TeethHistory{},
		&domain.PatientFile{},
		&domain.AuditLog{},
		&domain.Appointment{},
		&domain.ShiftAssignment{},
		&domain.ClinicTransaction{},
		&domain.ClinicInstallment{},
		&domain.Procedure{},
		&domain.Budget{},
		&domain.BudgetItem{},
		&domain.InventoryItem{},
		&domain.InventoryTransaction{},
		&domain.ProcedureMaterial{},
		&domain.Affiliate{},
		&domain.Coupon{},
		&domain.ReferralPartner{},
		&domain.PromoCode{},
		&domain.Subscription{},
		&domain.UsedCheckoutSession{},
	)
	if err != nil {
		log.Fatal("❌ Erro ao rodar migrations: ", err)
	}
	log.Println("✅ AutoMigrate concluído!")

	enableRLSAndPolicies()
	SeedRoles()
	SeedDefaultUser()
}

func enableRLSAndPolicies() {
	tables := []string{
		"clinics", "roles", "users", "rooms", "patients",
		"appointment_types", "appointments", "procedures", "budgets", "budget_items",
		"clinical_evolutions", "clinical_notes", "medical_documents",
		"teeth_status", "teeth_statuses", "teeth_history",
		"clinic_transactions", "audit_logs", "patient_files", "shift_assignments",
		"settings", "waitlists", "clinic_installments", "inventory_items",
		"inventory_transactions", "procedure_materials", "affiliates", "coupons",
		"referral_partners", "promo_codes", "subscriptions", "used_checkout_sessions",
	}

	for _, table := range tables {
		_ = DB.Exec(fmt.Sprintf("ALTER TABLE IF EXISTS public.%s ENABLE ROW LEVEL SECURITY;", table)).Error
		_ = DB.Exec(fmt.Sprintf("DROP POLICY IF EXISTS \"Allow Full Access to Backend Service\" ON public.%s;", table)).Error
		_ = DB.Exec(fmt.Sprintf("CREATE POLICY \"Allow Full Access to Backend Service\" ON public.%s FOR ALL TO postgres, service_role USING (true) WITH CHECK (true);", table)).Error
	}
	log.Println("✅ RLS e políticas de segurança aplicadas em todas as tabelas públicas")
}

func SeedRoles() {
	roles := []domain.Role{
		{Name: "owner", Permissions: `["manage_team", "manage_settings", "manage_billing", "view_reports", "manage_appointments"]`},
		{Name: "manager", Permissions: `["manage_team", "manage_settings", "view_reports", "manage_appointments"]`},
		{Name: "doctor", Permissions: `["manage_medical_records", "view_appointments"]`},
		{Name: "receptionist", Permissions: `["manage_appointments", "view_patients", "manage_waitlist"]`},
	}

	for _, role := range roles {
		var existingRole domain.Role
		if err := DB.Where("name = ?", role.Name).First(&existingRole).Error; err != nil {
			// Role não existe, criar
			DB.Create(&role)
			log.Printf("✅ Cargo %s criado com sucesso", role.Name)
		} else {
			// Atualizar permissões caso existam
			existingRole.Permissions = role.Permissions
			DB.Save(&existingRole)
		}
	}
}

func fixPostgresSequences() {
	tables := []string{
		"clinics", "roles", "users", "patients", "rooms", "settings",
		"appointment_types", "waitlists", "clinical_evolutions", "clinical_notes",
		"medical_documents", "teeth_statuses", "teeth_histories", "patient_files",
		"audit_logs", "appointments", "shift_assignments", "clinic_transactions",
		"clinic_installments", "procedures", "budgets", "budget_items",
		"inventory_items", "inventory_transactions", "procedure_materials", "subscriptions",
	}
	for _, table := range tables {
		_ = DB.Exec("SELECT setval(pg_get_serial_sequence('" + table + "', 'id'), COALESCE((SELECT MAX(id) FROM " + table + "), 0) + 1, false)").Error
	}
}

func SeedDefaultUser() {
	var ownerRole domain.Role
	if err := DB.Where("name = ?", "owner").First(&ownerRole).Error; err != nil {
		log.Println("Aviso: cargo owner não encontrado para seed de usuário padrão")
		return
	}

	trialEndsAt := time.Now().Add(365 * 24 * time.Hour)
	var clinic domain.Clinic
	if err := DB.Where("id = ? OR email = ?", 1, "admin@clinica.com").First(&clinic).Error; err != nil {
		clinic = domain.Clinic{
			Name:        "Clínica Odontológica Demo",
			CNPJ:        "00.000.000/0001-00",
			Email:       "admin@clinica.com",
			Status:      "active",
			TrialEndsAt: &trialEndsAt,
		}
		if err := DB.Create(&clinic).Error; err != nil {
			log.Printf("Aviso: erro ao criar clínica demo: %v", err)
			return
		}
	} else {
		clinic.Status = "active"
		if clinic.TrialEndsAt == nil || clinic.TrialEndsAt.Before(time.Now()) {
			clinic.TrialEndsAt = &trialEndsAt
		}
		DB.Save(&clinic)
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte("123456"), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("Aviso: erro ao gerar hash de senha para usuário padrão: %v", err)
		return
	}

	var user domain.User
	if err := DB.Where("email = ?", "admin@clinica.com").First(&user).Error; err != nil {
		user = domain.User{
			Name:     "Administrador Demo",
			Email:    "admin@clinica.com",
			Password: string(hashedPassword),
			ClinicID: clinic.ID,
			RoleID:   &ownerRole.ID,
		}
		if err := DB.Create(&user).Error; err != nil {
			log.Printf("Aviso: erro ao criar usuário padrão: %v", err)
		} else {
			log.Println("✅ Usuário padrão criado: admin@clinica.com / 123456")
		}
	} else {
		needsUpdate := false
		if bcrypt.CompareHashAndPassword([]byte(user.Password), []byte("123456")) != nil {
			user.Password = string(hashedPassword)
			needsUpdate = true
		}
		if user.RoleID == nil || *user.RoleID != ownerRole.ID {
			user.RoleID = &ownerRole.ID
			needsUpdate = true
		}
		if user.ClinicID != clinic.ID {
			user.ClinicID = clinic.ID
			needsUpdate = true
		}
		if user.FailedAttempts > 0 || user.LockedUntil != nil {
			user.FailedAttempts = 0
			user.LockedUntil = nil
			needsUpdate = true
		}
		if needsUpdate {
			DB.Save(&user)
			log.Println("✅ Usuário padrão atualizado e desbloqueado: admin@clinica.com / 123456")
		}
	}

	fixPostgresSequences()
}

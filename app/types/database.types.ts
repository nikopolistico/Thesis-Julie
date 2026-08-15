interface PatientRow {
  id: number
  full_name: string
  admission_date: string
  philhealth_no: string
  officer_id: number
  age: number | null
  date_of_birth: string | null
  contact_number: string | null
  emergency_contact: string | null
  room_number: number | null
  discharge_date: string | null
}

interface DischargeRequestRow {
  request_id: number
  patient_id: number
  requested_by: number
  status: string
  billing_verified: boolean
  timestamp: string
}

interface TaskRow {
  task_id: number
  discharge_id: number
  task_type: string
  status: string
}

interface OfficerRow {
  officer_id: number
  full_name: string
  role: string
  duty_status: string
}

export interface Database {
  public: {
    Tables: {
      administrator: {
        Row: {
          id: string
          email: string
          password: string
          created_at: string
        }
        Insert: {
          id?: string
          email: string
          password: string
          created_at?: string
        }
        Update: {
          id?: string
          email?: string
          password?: string
          created_at?: string
        }
        Relationships: []
      }
    }
    Views: Record<string, never>
    Functions: {
      register_administrator: {
        Args: { p_email: string; p_password: string }
        Returns: { id: string; email: string }[]
      }
      login_administrator: {
        Args: { p_email: string; p_password: string; p_role: string }
        Returns: { user_id: number; email: string; role: string }[]
      }
      create_patient: {
        Args: {
          p_full_name: string
          p_admission_date: string
          p_philhealth_no: string
          p_officer_id: number
          p_age: number | null
          p_date_of_birth: string | null
          p_contact_number: string | null
          p_emergency_contact: string | null
          p_room_number: number | null
          p_discharge_date: string | null
        }
        Returns: PatientRow[]
      }
      update_patient: {
        Args: {
          p_id: number
          p_full_name: string
          p_admission_date: string
          p_philhealth_no: string
          p_age: number | null
          p_date_of_birth: string | null
          p_contact_number: string | null
          p_emergency_contact: string | null
          p_room_number: number | null
          p_discharge_date: string | null
          p_officer_id: number
        }
        Returns: PatientRow[]
      }
      list_patients_by_officer: {
        Args: { p_officer_id: number }
        Returns: PatientRow[]
      }
      create_discharge_request: {
        Args: { p_patient_id: number; p_requested_by: number }
        Returns: DischargeRequestRow[]
      }
      update_discharge_request_status: {
        Args: { p_request_id: number; p_status: string; p_requested_by: number }
        Returns: DischargeRequestRow[]
      }
      list_discharge_requests_by_officer: {
        Args: { p_officer_id: number }
        Returns: (Omit<DischargeRequestRow, 'requested_by'> & { patient_name: string; discharge_date: string | null })[]
      }
      list_tasks_by_officer: {
        Args: { p_officer_id: number }
        Returns: (TaskRow & { patient_name: string })[]
      }
      update_task_status: {
        Args: { p_task_id: number; p_status: string; p_officer_id: number }
        Returns: TaskRow[]
      }
      list_officers_with_duty: {
        Args: Record<string, never>
        Returns: OfficerRow[]
      }
      set_officer_duty_status: {
        Args: { p_officer_id: number; p_duty_status: string; p_admin_id: number }
        Returns: OfficerRow[]
      }
      list_all_patients: {
        Args: Record<string, never>
        Returns: PatientRow[]
      }
      list_all_discharge_requests: {
        Args: Record<string, never>
        Returns: (Omit<DischargeRequestRow, 'requested_by'> & {
          patient_name: string
          requested_by: number
          requested_by_name: string
          approved_by: number | null
          approved_by_name: string | null
          discharge_date: string | null
        })[]
      }
      update_discharge_request_status_by_doctor: {
        Args: { p_request_id: number; p_status: string; p_doctor_id: number }
        Returns: (Omit<DischargeRequestRow, 'requested_by'> & {
          patient_name: string
          requested_by: number
          requested_by_name: string
          approved_by: number | null
          approved_by_name: string | null
          discharge_date: string | null
        })[]
      }
      get_officer_name: {
        Args: { p_officer_id: number }
        Returns: string
      }
      register_staff: {
        Args: { p_email: string; p_password: string; p_full_name: string; p_role: string; p_admin_id: number }
        Returns: { officer_id: number; full_name: string; email: string; role: string; duty_status: string }[]
      }
    }
    Enums: Record<string, never>
    CompositeTypes: Record<string, never>
  }
}

interface PatientRow {
  patient_id: number
  full_name: string
  date_of_birth: string | null
  age: number | null
  contact_number: string | null
  emergency_contact: string | null
  admission_date: string
  discharge_date: string | null
  room_number: number | null
  philhealth_no: string | null
  attending_officer_id: number | null
  created_at: string
}

interface DischargeRequestRow {
  request_id: number
  patient_id: number
  requested_by: number
  approved_by: number | null
  status: string
  billing_verified: boolean
  timestamp: string
}

interface DischargeRequestByRequesterRow {
  request_id: number
  patient_id: number
  patient_name: string
  status: string
  billing_verified: boolean
  timestamp: string
}

interface DischargeRequestDetailedRow {
  request_id: number
  patient_id: number
  patient_name: string
  requested_by: number
  requested_by_name: string
  approved_by: number | null
  approved_by_name: string | null
  status: string
  billing_verified: boolean
  timestamp: string
}

interface TaskRow {
  task_id: number
  discharge_request_id: number
  assigned_to: number | null
  task_type: string
  status: string
  created_at: string
  completed_at: string | null
}

interface TaskDetailedRow {
  task_id: number
  discharge_request_id: number
  patient_id: number
  patient_name: string
  task_type: string
  status: string
  created_at: string
  completed_at: string | null
}

interface OfficerRow {
  officer_id: number
  full_name: string
  role: string
  duty_status: string
  created_at: string
}

export interface BillingRow {
  billing_id: number
  discharge_request_id: number
  patient_id: number
  handled_by: number | null
  total_amount: number
  philhealth_deduction: number
  status: string
  created_at: string
}

interface LoginResultRow {
  officer_id: number
  full_name: string
  email: string
  role: string
  duty_status: string
}

export interface Database {
  public: {
    Tables: Record<string, never>
    Views: Record<string, never>
    Functions: {
      login_officer: {
        Args: { p_email: string; p_password: string }
        Returns: LoginResultRow[]
      }
      register_officer: {
        Args: { p_email: string; p_password: string; p_full_name: string; p_role: string; p_admin_id: number | null }
        Returns: LoginResultRow[]
      }
      set_duty_status: {
        Args: { p_officer_id: number; p_duty_status: string }
        Returns: OfficerRow
      }
      register_patient: {
        Args: {
          p_full_name: string
          p_date_of_birth: string | null
          p_age: number | null
          p_contact_number: string | null
          p_emergency_contact: string | null
          p_room_number: number | null
          p_philhealth_no: string | null
          p_attending_officer_id: number | null
        }
        Returns: PatientRow
      }
      update_patient_info: {
        Args: {
          p_patient_id: number
          p_contact_number?: string | null
          p_emergency_contact?: string | null
          p_room_number?: number | null
          p_attending_officer_id?: number | null
        }
        Returns: PatientRow
      }
      create_discharge_request: {
        Args: { p_patient_id: number; p_requested_by: number }
        Returns: number
      }
      complete_task: {
        Args: { p_task_id: number }
        Returns: TaskRow
      }
      list_tasks_for_officer: {
        Args: { p_officer_id: number }
        Returns: TaskRow[]
      }
      list_tasks_for_officer_detailed: {
        Args: { p_officer_id: number }
        Returns: TaskDetailedRow[]
      }
      create_billing_record: {
        Args: { p_discharge_request_id: number; p_patient_id: number; p_total_amount: number; p_philhealth_deduction: number }
        Returns: BillingRow
      }
      verify_billing: {
        Args: { p_billing_id: number }
        Returns: BillingRow
      }
      approve_discharge_request: {
        Args: { p_request_id: number; p_approved_by: number }
        Returns: DischargeRequestRow
      }
      reject_discharge_request: {
        Args: { p_request_id: number; p_rejected_by: number }
        Returns: DischargeRequestRow
      }
      complete_discharge_request: {
        Args: { p_request_id: number }
        Returns: DischargeRequestRow
      }
      get_discharge_request_details: {
        Args: { p_request_id: number }
        Returns: {
          request_id: number
          status: string
          billing_verified: boolean
          patient_full_name: string
          tasks_json: TaskRow[]
          billing_json: BillingRow[]
        }
      }
      list_discharge_requests: {
        Args: { p_status?: string | null }
        Returns: DischargeRequestRow[]
      }
      list_discharge_requests_by_requester: {
        Args: { p_officer_id: number }
        Returns: DischargeRequestByRequesterRow[]
      }
      list_discharge_requests_detailed: {
        Args: { p_status?: string | null }
        Returns: DischargeRequestDetailedRow[]
      }
      list_patients_by_officer: {
        Args: { p_officer_id: number }
        Returns: PatientRow[]
      }
      list_all_patients: {
        Args: Record<string, never>
        Returns: PatientRow[]
      }
      list_officers: {
        Args: Record<string, never>
        Returns: OfficerRow[]
      }
    }
    Enums: Record<string, never>
    CompositeTypes: Record<string, never>
  }
}

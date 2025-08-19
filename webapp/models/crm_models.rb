require 'json'
require 'fileutils'
require 'time'

# CRM Models for Sales Tools Projects
class CRMDataManager
  def initialize
    @crm_data_dir = File.join(File.dirname(__FILE__), '..', 'data', 'crm')
    ensure_crm_directory
  end

  private

  def ensure_crm_directory
    FileUtils.mkdir_p(@crm_data_dir) unless Dir.exist?(@crm_data_dir)
  end

  def get_data_file(filename)
    File.join(@crm_data_dir, filename)
  end

  def load_json_data(filename)
    file_path = get_data_file(filename)
    if File.exist?(file_path)
      JSON.parse(File.read(file_path))
    else
      []
    end
  rescue => e
    puts "Error loading #{filename}: #{e.message}"
    []
  end

  def save_json_data(filename, data)
    file_path = get_data_file(filename)
    File.write(file_path, JSON.pretty_generate(data))
  rescue => e
    puts "Error saving #{filename}: #{e.message}"
    false
  end
end

# Organization Management
class OrganizationManager < CRMDataManager
  def list_organizations
    load_json_data('organizations.json')
  end

  def get_organization(id)
    organizations = list_organizations
    organizations.find { |org| org['id'] == id }
  end

  def create_organization(org_data)
    organizations = list_organizations
    new_org = {
      'id' => generate_id,
      'name' => org_data['name'],
      'industry' => org_data['industry'],
      'organization_types' => org_data['organization_types'] || ['Customer'],
      'website' => org_data['website'],
      'address' => org_data['address'],
      'phone' => org_data['phone'],
      'email' => org_data['email'],
      'annual_revenue' => org_data['annual_revenue'],
      'employee_count' => org_data['employee_count'],
      'notes' => org_data['notes'],
      'created_at' => Time.now.iso8601,
      'updated_at' => Time.now.iso8601
    }
    organizations << new_org
    save_json_data('organizations.json', organizations)
    new_org
  end

  def list_organizations_by_type(type = nil)
    organizations = list_organizations
    if type
      organizations.select { |org| org['organization_types']&.include?(type) }
    else
      organizations
    end
  end

  def update_organization(id, org_data)
    organizations = list_organizations
    org_index = organizations.find_index { |org| org['id'] == id }
    return nil unless org_index

    organizations[org_index].merge!(org_data)
    organizations[org_index]['updated_at'] = Time.now.iso8601
    save_json_data('organizations.json', organizations)
    organizations[org_index]
  end

  def delete_organization(id)
    organizations = list_organizations
    organizations.reject! { |org| org['id'] == id }
    save_json_data('organizations.json', organizations)
  end

  private

  def generate_id
    SecureRandom.uuid
  end
end

# Contact Management
class ContactManager < CRMDataManager
  def list_contacts(organization_id = nil)
    contacts = load_json_data('contacts.json')
    if organization_id
      contacts.select { |contact| contact['organization_id'] == organization_id }
    else
      contacts
    end
  end

  def get_contact(id)
    contacts = list_contacts
    contacts.find { |contact| contact['id'] == id }
  end

  def create_contact(contact_data)
    contacts = list_contacts
    new_contact = {
      'id' => generate_id,
      'organization_id' => contact_data['organization_id'],
      'first_name' => contact_data['first_name'],
      'last_name' => contact_data['last_name'],
      'title' => contact_data['title'],
      'email' => contact_data['email'],
      'phone' => contact_data['phone'],
      'mobile' => contact_data['mobile'],
      'linkedin' => contact_data['linkedin'],
      'is_primary' => contact_data['is_primary'] || false,
      'notes' => contact_data['notes'],
      'created_at' => Time.now.iso8601,
      'updated_at' => Time.now.iso8601
    }
    contacts << new_contact
    save_json_data('contacts.json', contacts)
    new_contact
  end

  def update_contact(id, contact_data)
    contacts = list_contacts
    contact_index = contacts.find_index { |contact| contact['id'] == id }
    return nil unless contact_index

    contacts[contact_index].merge!(contact_data)
    contacts[contact_index]['updated_at'] = Time.now.iso8601
    save_json_data('contacts.json', contacts)
    contacts[contact_index]
  end

  def delete_contact(id)
    contacts = list_contacts
    contacts.reject! { |contact| contact['id'] == id }
    save_json_data('contacts.json', contacts)
  end

  private

  def generate_id
    SecureRandom.uuid
  end
end

# Activity Management
class ActivityManager < CRMDataManager
  def list_activities(project_id = nil, organization_id = nil)
    activities = load_json_data('activities.json')
    activities = activities.select { |activity| activity['project_id'] == project_id } if project_id
    activities = activities.select { |activity| activity['organization_id'] == organization_id } if organization_id
    activities.sort_by { |activity| activity['date'] }.reverse
  end

  def get_activity(id)
    activities = list_activities
    activities.find { |activity| activity['id'] == id }
  end

  def create_activity(activity_data)
    activities = list_activities
    new_activity = {
      'id' => generate_id,
      'project_id' => activity_data['project_id'],
      'project_type' => activity_data['project_type'],
      'organization_id' => activity_data['organization_id'],
      'contact_id' => activity_data['contact_id'],
      'type' => activity_data['type'],
      'subject' => activity_data['subject'],
      'description' => activity_data['description'],
      'date' => activity_data['date'] || Time.now.iso8601,
      'duration' => activity_data['duration'],
      'outcome' => activity_data['outcome'],
      'next_action' => activity_data['next_action'],
      'next_action_date' => activity_data['next_action_date'],
      'created_at' => Time.now.iso8601,
      'updated_at' => Time.now.iso8601
    }
    activities << new_activity
    save_json_data('activities.json', activities)
    new_activity
  end

  def update_activity(id, activity_data)
    activities = list_activities
    activity_index = activities.find_index { |activity| activity['id'] == id }
    return nil unless activity_index

    activities[activity_index].merge!(activity_data)
    activities[activity_index]['updated_at'] = Time.now.iso8601
    save_json_data('activities.json', activities)
    activities[activity_index]
  end

  def delete_activity(id)
    activities = list_activities
    activities.reject! { |activity| activity['id'] == id }
    save_json_data('activities.json', activities)
  end

  private

  def generate_id
    SecureRandom.uuid
  end
end

# Note Management
class NoteManager < CRMDataManager
  def list_notes(project_id = nil, organization_id = nil)
    notes = load_json_data('notes.json')
    notes = notes.select { |note| note['project_id'] == project_id } if project_id
    notes = notes.select { |note| note['organization_id'] == organization_id } if organization_id
    notes.sort_by { |note| note['created_at'] }.reverse
  end

  def get_note(id)
    notes = list_notes
    notes.find { |note| note['id'] == id }
  end

  def create_note(note_data)
    notes = list_notes
    new_note = {
      'id' => generate_id,
      'project_id' => note_data['project_id'],
      'project_type' => note_data['project_type'],
      'organization_id' => note_data['organization_id'],
      'contact_id' => note_data['contact_id'],
      'title' => note_data['title'],
      'content' => note_data['content'],
      'category' => note_data['category'],
      'is_private' => note_data['is_private'] || false,
      'created_at' => Time.now.iso8601,
      'updated_at' => Time.now.iso8601
    }
    notes << new_note
    save_json_data('notes.json', notes)
    new_note
  end

  def update_note(id, note_data)
    notes = list_notes
    note_index = notes.find_index { |note| note['id'] == id }
    return nil unless note_index

    notes[note_index].merge!(note_data)
    notes[note_index]['updated_at'] = Time.now.iso8601
    save_json_data('notes.json', notes)
    notes[note_index]
  end

  def delete_note(id)
    notes = list_notes
    notes.reject! { |note| note['id'] == id }
    save_json_data('notes.json', notes)
  end

  private

  def generate_id
    SecureRandom.uuid
  end
end

# Sales Pipeline Management
class PipelineManager < CRMDataManager
  # Standard sales pipeline stages
  PIPELINE_STAGES = {
    'lead' => {
      'name' => 'Lead',
      'description' => 'Initial contact or inquiry',
      'probability' => 10,
      'color' => '#6c757d'
    },
    'qualified' => {
      'name' => 'Qualified Lead',
      'description' => 'Lead has been qualified and shows interest',
      'probability' => 25,
      'color' => '#17a2b8'
    },
    'proposal' => {
      'name' => 'Proposal',
      'description' => 'Proposal has been sent',
      'probability' => 50,
      'color' => '#ffc107'
    },
    'negotiation' => {
      'name' => 'Negotiation',
      'description' => 'In negotiation phase',
      'probability' => 75,
      'color' => '#fd7e14'
    },
    'closed_won' => {
      'name' => 'Closed Won',
      'description' => 'Deal has been won',
      'probability' => 100,
      'color' => '#28a745'
    },
    'closed_lost' => {
      'name' => 'Closed Lost',
      'description' => 'Deal has been lost',
      'probability' => 0,
      'color' => '#dc3545'
    }
  }

  def get_pipeline_stages
    PIPELINE_STAGES
  end

  def list_pipeline_entries(project_id = nil, organization_id = nil)
    entries = load_json_data('pipeline.json')
    entries = entries.select { |entry| entry['project_id'] == project_id } if project_id
    entries = entries.select { |entry| entry['organization_id'] == organization_id } if organization_id
    entries.sort_by { |entry| entry['updated_at'] }.reverse
  end

  def get_pipeline_entry(id)
    entries = list_pipeline_entries
    entries.find { |entry| entry['id'] == id }
  end

  def create_pipeline_entry(entry_data)
    entries = list_pipeline_entries
    new_entry = {
      'id' => generate_id,
      'project_id' => entry_data['project_id'],
      'project_type' => entry_data['project_type'],
      'organization_id' => entry_data['organization_id'],
      'contact_id' => entry_data['contact_id'],
      'stage' => entry_data['stage'] || 'lead',
      'value' => entry_data['value'],
      'currency' => entry_data['currency'] || 'USD',
      'expected_close_date' => entry_data['expected_close_date'],
      'actual_close_date' => entry_data['actual_close_date'],
      'win_probability' => entry_data['win_probability'],
      'win_reason' => entry_data['win_reason'],
      'loss_reason' => entry_data['loss_reason'],
      'notes' => entry_data['notes'],
      'next_action' => entry_data['next_action'],
      'next_action_date' => entry_data['next_action_date'],
      'created_at' => Time.now.iso8601,
      'updated_at' => Time.now.iso8601
    }
    entries << new_entry
    save_json_data('pipeline.json', entries)
    new_entry
  end

  def update_pipeline_entry(id, entry_data)
    entries = list_pipeline_entries
    entry_index = entries.find_index { |entry| entry['id'] == id }
    return nil unless entry_index

    entries[entry_index].merge!(entry_data)
    entries[entry_index]['updated_at'] = Time.now.iso8601
    save_json_data('pipeline.json', entries)
    entries[entry_index]
  end

  def delete_pipeline_entry(id)
    entries = list_pipeline_entries
    entries.reject! { |entry| entry['id'] == id }
    save_json_data('pipeline.json', entries)
  end

  def get_pipeline_summary
    entries = list_pipeline_entries
    summary = {
      'total_entries' => entries.length,
      'total_value' => entries.sum { |entry| entry['value'].to_f || 0 },
      'by_stage' => {},
      'recent_activities' => entries.first(10)
    }

    PIPELINE_STAGES.each do |stage_key, stage_info|
      stage_entries = entries.select { |entry| entry['stage'] == stage_key }
      summary['by_stage'][stage_key] = {
        'name' => stage_info['name'],
        'count' => stage_entries.length,
        'value' => stage_entries.sum { |entry| entry['value'].to_f || 0 },
        'probability' => stage_info['probability']
      }
    end

    summary
  end

  private

  def generate_id
    SecureRandom.uuid
  end
end

# Main CRM Manager that coordinates all CRM operations
class CRMManager < CRMDataManager
  def initialize
    super
    @organizations = OrganizationManager.new
    @contacts = ContactManager.new
    @activities = ActivityManager.new
    @notes = NoteManager.new
    @pipeline = PipelineManager.new
  end

  # Organization methods
  def list_organizations
    @organizations.list_organizations
  end

  def list_organizations_by_type(type = nil)
    @organizations.list_organizations_by_type(type)
  end

  def get_organization(id)
    @organizations.get_organization(id)
  end

  def create_organization(org_data)
    @organizations.create_organization(org_data)
  end

  def update_organization(id, org_data)
    @organizations.update_organization(id, org_data)
  end

  def delete_organization(id)
    @organizations.delete_organization(id)
  end

  # Contact methods
  def list_contacts(organization_id = nil)
    @contacts.list_contacts(organization_id)
  end

  def get_contact(id)
    @contacts.get_contact(id)
  end

  def create_contact(contact_data)
    @contacts.create_contact(contact_data)
  end

  def update_contact(id, contact_data)
    @contacts.update_contact(id, contact_data)
  end

  def delete_contact(id)
    @contacts.delete_contact(id)
  end

  # Activity methods
  def list_activities(project_id = nil, organization_id = nil)
    @activities.list_activities(project_id, organization_id)
  end

  def get_activity(id)
    @activities.get_activity(id)
  end

  def create_activity(activity_data)
    @activities.create_activity(activity_data)
  end

  def update_activity(id, activity_data)
    @activities.update_activity(id, activity_data)
  end

  def delete_activity(id)
    @activities.delete_activity(id)
  end

  # Note methods
  def list_notes(project_id = nil, organization_id = nil)
    @notes.list_notes(project_id, organization_id)
  end

  def get_note(id)
    @notes.get_note(id)
  end

  def create_note(note_data)
    @notes.create_note(note_data)
  end

  def update_note(id, note_data)
    @notes.update_note(id, note_data)
  end

  def delete_note(id)
    @notes.delete_note(id)
  end

  # Pipeline methods
  def get_pipeline_stages
    @pipeline.get_pipeline_stages
  end

  def list_pipeline_entries(project_id = nil, organization_id = nil)
    @pipeline.list_pipeline_entries(project_id, organization_id)
  end

  def get_pipeline_entry(id)
    @pipeline.get_pipeline_entry(id)
  end

  def create_pipeline_entry(entry_data)
    @pipeline.create_pipeline_entry(entry_data)
  end

  def update_pipeline_entry(id, entry_data)
    @pipeline.update_pipeline_entry(id, entry_data)
  end

  def delete_pipeline_entry(id)
    @pipeline.delete_pipeline_entry(id)
  end

  def get_pipeline_summary
    @pipeline.get_pipeline_summary
  end

  # Project-specific methods
  def get_project_crm_data(project_id, project_type)
    {
      'organizations' => list_organizations,
      'contacts' => list_contacts,
      'activities' => list_activities(project_id),
      'notes' => list_notes(project_id),
      'pipeline_entries' => list_pipeline_entries(project_id),
      'pipeline_stages' => get_pipeline_stages,
      'pipeline_summary' => get_pipeline_summary
    }
  end

  # Project linking methods
  def link_project_to_organization(project_id, project_type, organization_id)
    project_links = load_json_data('project_links.json')
    
    # Remove any existing links for this project
    project_links.reject! { |link| link['project_id'] == project_id && link['project_type'] == project_type }
    
    # Add new link
    new_link = {
      'id' => generate_id,
      'project_id' => project_id,
      'project_type' => project_type,
      'organization_id' => organization_id,
      'linked_at' => Time.now.iso8601
    }
    
    project_links << new_link
    save_json_data('project_links.json', project_links)
    new_link
  end

  def unlink_project_from_organization(project_id, project_type)
    project_links = load_json_data('project_links.json')
    project_links.reject! { |link| link['project_id'] == project_id && link['project_type'] == project_type }
    save_json_data('project_links.json', project_links)
    { success: true, message: 'Project unlinked successfully' }
  end

  def get_project_organization(project_id, project_type)
    project_links = load_json_data('project_links.json')
    link = project_links.find { |link| link['project_id'] == project_id && link['project_type'] == project_type }
    
    if link
      organization = get_organization(link['organization_id'])
      {
        'link' => link,
        'organization' => organization
      }
    else
      nil
    end
  end

  def get_organization_projects(organization_id)
    project_links = load_json_data('project_links.json')
    links = project_links.select { |link| link['organization_id'] == organization_id }
    
    links.map do |link|
      {
        'link' => link,
        'project_info' => {
          'id' => link['project_id'],
          'type' => link['project_type'],
          'name' => link['project_id'] # This will be enhanced with actual project names
        }
      }
    end
  end

  def get_all_project_links
    load_json_data('project_links.json')
  end

  private

  def generate_id
    SecureRandom.uuid
  end
end

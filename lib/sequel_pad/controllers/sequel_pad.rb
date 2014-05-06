class SequelPadController < RubyFx::Controller
  JFile = java.io.File
  attr_accessor :db, :web_views_root, :editor_url
  
  # Initialization methods
  # ----------------------
  
  # Constructor
  def initialize
    @connected = false
    @page_size = 25
    self.web_views_root = "#{File.dirname(__FILE__)}/../web_views"
  end
  
  # Performs post-fxml-load initializations and shows the stage
  def start
    load_ace_editor
    @root_pane.add_event_filter RubyFx::KeyEvent::KEY_PRESSED do |event|
      if event.code == RubyFx::KeyCode::F5
        run_script
      end
    end
    load_results_web_view
    RubyFx.web_hub(self, @results_web_view, 'hub') do |hub|
      @server_hub = hub
    end
    stage.show
  end

  # Initializes the web view where results are displayed
  def load_results_web_view
    @results_web_view.engine.load(file_url("#{web_views_root}/results_table.html"))
  end
  
  # Initializes the web view containing the Ace code editor
  def load_ace_editor
    @editor_url =  file_url("#{web_views_root}/ace_editor.html")
    @web_view.engine.load(editor_url)
  end

  # Event Handlers
  # --------------
  
  def on_save_as
    file = RubyFx.save_file
    File.open(file.to_s, "w") do |f|
      f.write(script_text)
    end
  end

  def on_open
    file = RubyFx.open_file
    File.open(file.to_s, "r") do |f|
      self.script_text = f.read()
    end
  end

  # Runs the client's currect script. Triggered by F5
  def run_script
    @logs_text_area.clear
    if_connected do
      @result = self.instance_eval script_text
      if @result.kind_of? Sequel::JDBC::Dataset
        @total_pages_label.text = "/ #{total_pages}"
        @server_hub.onNewQueryPerformed @result.columns
        show_results_tab
      elsif @result.kind_of? Hash
        @total_pages_label.text = "/ 1"
        @server_hub.onNewQueryPerformed @result.keys
        show_results_tab
      elsif @result.kind_of? Array
        @total_pages_label.text = "/ 1"
        @server_hub.onNewQueryPerformed (1..@result.length).to_a
        show_results_tab
      else
        if @logs_text_area.text.length == 0
          log (@result.nil? ? 'nil' : @result.to_s)
        end
        show_logs_tab
      end
      java.lang.System.gc
    end
  rescue Exception => ex
    log ex.to_s
    puts ex
    ex.printStackTrace(java.lang.System.out) if ex.respond_to? :printStackTrace
    puts "Source: #{ex.source}" if ex.respond_to? :source
    show_logs_tab
  end

  # Shows the selected page of data to the user
  def on_page_change
    return unless paging_enabled
    if_connected do
      @server_hub.onNewQueryPerformed @result.columns
    end
  end

  # Shows the next page of results
  def on_next
    if !paging_enabled || page_number == total_pages
      return
    end
    self.page_number += 1
    on_page_change
  end

  # Shows the previous page of results
  def on_prev
    if !paging_enabled || page_number == 0
      return
    end
    self.page_number -= 1
    on_page_change
  end

  def paging_enabled
    @connected && !(@result.kind_of?(Hash) || @result.kind_of?(Array))
  end

  # Toggles the Sequel connection
  def on_connect_button_pressed
    if @connected
      disconnect
    else
      connect
    end
  end

  # Shows the tables in the newly selected schema
  def on_select_schema
    if @connected
      list_tables
    end
  end
  
  # Opens a pry session in the console
  def on_pry
    binding.pry
  end

  # Reloads the ruby scripts for this program for quick debugging.
  def on_reload
    reload
  end

  # Web Hub Methods
  # ---------------

  # Note: The client hub may call any method it wants. These
  #       methods were just specifically created as hub endpoints.

  def get_data opts
    @server_hub.onNewData([]) if @result.nil?
    if @result.kind_of? Hash
      get_hash_data 
    elsif @result.kind_of? Array
      get_array_data
    else
      get_data_set_data
    end
  end
    
  def get_data_set_data
    page_number = self.page_number
    page = @result.paginate(page_number, @page_size)
    # Datatables expects an object of the form {data: [[value1, value2...]]}
    @server_hub.onNewData data: (page.to_a.map { |item| item.values.to_a })
  end

  def get_hash_data
    @server_hub.onNewData data: [@result.values.to_a]
  end

  def get_array_data
    @server_hub.onNewData data: [@result]
  end

  # Utility Methods
  # ---------------

  def list_tables
    if_connected do
      tables = tables_in_selected_schema
      tables = apply_table_filter tables
      tables = apply_column_filter tables
      @table_list_view.items.set_all(tables.sort)
    end
  end

  def connect
    @db = Sequel.connect(
      "jdbc:postgresql://" +
      "#{host}" +
      "#{port.length > 0 ? ":#{port}" : "" }" +
      "/#{database}?" +
      "#{username.length > 0 ? "user=#{username}" : "" }" +
      "#{password.length > 0 ? "&password=#{password}" : "" }"
    )
    @db.extension(:pagination)
    @connected = true
    @schema_combo_box.items.set_all @db[
      'select schema_name from information_schema.schemata'
    ].map { |schema_entry|
      schema_entry[:schema_name]  
    }
    @schema_combo_box.selection_model.select_first
    @connect_button.text = "Disconnect"
  rescue Exception => ex
    log ex
    show_logs_tab
  end

  def disconnect
    @connected = false
    @db.disconnect
    @db = nil
    @result = nil
    @schema_combo_box.selection_model.clear_selection
    @schema_combo_box.items.set_all ["(Empty)"]
    @schema_combo_box.selection_model.select_first
    @table_list_view.items.clear
    @connect_button.text = "Connect"
  end
  
  def apply_table_filter tables
    if table_filter.length == 0
      tables
    else
      table_regexp = Regexp.new(table_filter, Regexp::IGNORECASE)
      tables.grep table_regexp
    end
  end
  
  def apply_column_filter tables
    if column_filter.length == 0
      tables
    else
      column_regexp = Regexp.new(column_filter, Regexp::IGNORECASE)
      tables.select { |table|
        columns = @db["#{schema.length > 0 ? "#{schema}__" : "" }#{table}".to_sym].columns
        columns.any? { |column| column =~ column_regexp }
      }
    end
  end
  
  def prompt_for_connection
    @logs_text_area.clear
    log "Not connected to a database"
    show_logs_tab
  end

  def log message
    @logs_text_area.append_text "#{message}\n"
  end
    
  def show_logs_tab
    @logs_tab.tab_pane.selection_model.select @logs_tab
  end
  
  def show_results_tab
    @results_tab.tab_pane.selection_model.select @results_tab
  end
  
  def method_missing name, *args, &block
    all_tables = tables_in_selected_schema
    matching_tables = all_tables.select { |t|
      t == name
    }
    
    # If no matches, fall back to case-insensitive search
    if matching_tables.length == 0
      matching_tables = all_tables.select { |t|
        t.downcase == name.downcase  
      }
    end
    
    if matching_tables.length > 0
      table_name = matching_tables.first
      db["#{schema.length > 0 ? "#{schema}__" : "" }#{table_name}".to_sym]
    else
      puts "Unkown method '#{name}' called with '#{args.join ", "}'"
    end
  end

  # Getters / Setters
  # -----------------

  [:host, :port, :database, :username, :password, 
    :table_filter, :column_filter].each do |field|
    define_method field do
      instance_variable_get("@#{field}_text_field").text
    end
    
    define_method "#{field}=" do |val|
      instance_variable_get("@#{field}_text_field").text = val
    end
  end

  def page_number
    text_value = @page_number_text_field.text
    unless text_value =~ /^\s*[0-9]+\s*$/
      self.page_number = 1 
      return 1
    end
    numeric_value = text_value.to_i
    if numeric_value < 1
      self.page_number = 1
      1
    elsif numeric_value > total_pages
      self.page_number = total_pages
      total_pages
    else
      numeric_value
    end
  end

  def page_number=(newValue)
    @page_number_text_field.text = newValue.to_s
  end

  def total_pages
    return 0 if @result.nil?
    result_count = @result.count
    if result_count == 0
      0
    else
      (result_count.to_f / @page_size).ceil
    end
  end

  def total_results
    return 0 if @result.nil?
    @result.count
  end

  def tables_in_selected_schema
    if !schema.nil? && schema.length > 0
      @db.tables(schema: schema)
    else
      @db.tables
    end
  end

  def script_text
    @web_view.engine.execute_script "ace.edit('editor').getSession().getValue()"
  end

  def script_text=(new_value)
    @web_view.engine.execute_script(
      "ace.edit('editor').getSession().setValue('#{new_value.gsub("'", "\\\\'").gsub('"', '\\"')}')"
    )
  end

  def schema
    @schema_combo_box.selection_model.selected_item
  end

  def file_url path
    JFile.new(path).toURL.toString
  end
  
  def if_connected
    if @connected
      yield
    else
      prompt_for_connection
    end
  end
end
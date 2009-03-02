#!/usr/bin/env ruby

require 'fileutils'
require 'pp'
require 'yaml'


# ------------------------------ Classes ------------------------------ #


class MySQL2SqliteConverter
  def initialize( args )
    init_result = ( args.length == 1 ) ? init_from_yaml( args ) : init_from_command_line( args )

    @file_deletion_delay = 3
    
    if ( init_result && @database_name && @username && @password )
      @output_file = @database_name + ".sql"
      @sqlite_database = @database_name + ".sqlite"
    else
      puts "ERROR: Could not initialize MySQL2SqliteConverter: "
      pp( args )
      exit
    end
  end
  
  
  def mysql_to_sqlite()
    handle_existing_files()
    
    arr = Array[]

    IO.popen( "mysqldump -u #{@username} -p#{@password} --compact --compatible=ansi --complete-insert --skip-extended-insert --default-character-set=binary #{@database_name}" ) do |pipe|
      pipe.each_line do |line|
        next if contains_disallowed_sql( line )
        
        line = translate_sql_differences( line )
        line = translate_character_differences( line )
       
        arr << line
      end 
    end
    
    @line_count = arr.length
    
    complete_str = arr.join( '' )
    complete_str.gsub!( /,\n\);/, "\);\n" )
    
    puts "Writing out to: #{@output_file}"
    File.open( @output_file, 'w') { |f| f.write( complete_str ) }
    
    puts "Writing out to: #{@sqlite_database}"
    return system( "cat #{@output_file} | sqlite3 #{@sqlite_database}" )
  end
  
private 

  
  def init_from_yaml( args )
    if ( true == File.exists?( args[0] ) )
      ruby_obj = YAML::load_file( args[0] )
      config = ruby_obj[ 'config' ]
      
      return ( !config.nil? ) ? init( config['database'], config['username'], config['password'] ) : false
    else
      return false
    end
  end
  
  
  def init_from_command_line( args )
    return ( 3 == args.length ) ? init( args[0], args[1], args[2] ) : false
  end
  
  
  def init( database_name, username, password )
    @database_name, @username, @password = database_name, username, password
    return true
  end


  def handle_existing_files()
    handle_existing_file( @output_file )
    handle_existing_file( @sqlite_database )
  end
  
  
  def handle_existing_file( file )
    # TODO: Replace this with a query to the user, defaulting to Y
    if ( File.exists?( file ) )
      (1..@file_deletion_delay).each do |count|
        puts "WARNING: File #{file} already exists and will be over-written in  #{@file_deletion_delay - count} seconds. Press ctl-C to Quit"
        sleep 1
      end
      
      FileUtils.rm( file ) 
    end
  end
  
  
  # Don't attempt to include lines of MySQL data that Sqlite doesn't recognize
  def contains_disallowed_sql( line )
    return true if line.include?( 'KEY "' )
    return true if line.include?( 'UNIQUE KEY ' )
    return true if line.include?( 'PRIMARY KEY ' )
    return false
  end
  
  
  # Replaces the MySQL terms with Sqlite-friendly terms
  def translate_sql_differences( line )
    line.gsub!( /unsigned /, '' )
    line.gsub!( /auto_increment/, ' primary key' )
    line.gsub!( /smallint\([0-9]*\)/, 'integer' )
    line.gsub!( /tinyint\([0-9]*\)/, 'integer' )
    line.gsub!( /int\([0-9]*\)/, 'integer' )
    line.gsub!( /character set [^ ]*/, '' )
    line.gsub!( /enum\([^)]*\)/, 'varchar(255)' )
    line.gsub!( /on update [^,]*/, '' )
    
    return line
  end
  
  
  # Replace other syntactic differences
  def translate_character_differences( line )
    line.gsub!( /\`/, '"' )
    line.gsub!( /\\'/, '\'\'' )
    
    return line
  end
end


# ------------------------------ Main ------------------------------ #


if __FILE__ == $0
  # Requires: database name, database user and password or a config file
  if ( ARGV.length == 0 )
    puts "Usage: ./mysql2sqlite.rb database_name username password "
    puts "   or: ./mysql2sqlite.rb config_file.yaml"
    exit
  end

  conv = MySQL2SqliteConverter.new( ARGV )
  result = conv.mysql_to_sqlite()
  
  puts ( result ) ? "Done" : "Output failed"
  
  exit
end
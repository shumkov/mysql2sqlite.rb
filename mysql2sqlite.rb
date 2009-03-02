#!/usr/bin/env ruby

require 'fileutils'


# ------------------------------ Classes ------------------------------ #


class MySQL2SqliteConverter
  def initialize( database_name, username, password )
    @database_name = database_name
    @username = username
    @password = password
    @rm_delay = 3
    
    @output_file = @database_name + ".sql"
    @sqlite_database = @database_name + ".sqlite"
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


  def handle_existing_files()
    handle_existing_file( @output_file )
    handle_existing_file( @sqlite_database )
  end
  
  
  def handle_existing_file( file )
    # TODO: Replace this with a query to the user, defaulting to Y
    if ( File.exists?( file ) )
      (1..@rm_delay).each do |count|
        puts "WARNING: File #{file} already exists and will be over-written in  #{@rm_delay - count} seconds. Press ctl-C to Quit"
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
  # Requires: database name, database user and password
  if ( ARGV.length == 0 )
    puts "Usage: $0 <database name> $1 <database user> $2 <database password>"
    exit
  end

  conv = MySQL2SqliteConverter.new( ARGV[0], ARGV[1], ARGV[2] )
  result = conv.mysql_to_sqlite()
  
  puts ( result ) ? "Done" : "Output failed"
  
  exit
end
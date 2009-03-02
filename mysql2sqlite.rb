#!/usr/bin/env ruby

require 'fileutils'


# ------------------------------ Classes ------------------------------ #


class MySQL2SqliteConverter
  
  def initialize( database_name, username, password )
    @database_name = database_name
    @username = username
    @password = password
    @rm_delay = 1
    
    @output_file = @database_name + ".sql"
    @sqlite_file = @database_name + ".sqlite"
  end
  
  
  def handle_existing_file()
    if ( File.exists?( @output_file ) )
      (1..@rm_delay).each do |count|
        puts "Sqlite file #{@output_file} already exists. This file will be overwritten in  #{@rm_delay - count} seconds. Press ctl-C to stop"
        sleep 1
      end
      
      FileUtils.rm( @output_file ) 
    end
  end
  
  
  def mysql_to_sqlite()
    arr = Array[]

    IO.popen( "mysqldump -u #{@username} -p#{@password} --compact --compatible=ansi --complete-insert --skip-extended-insert --default-character-set=binary #{@database_name}" ) do |pipe|
      pipe.each_line do |line|
        # Don't attempt to include lines of MySQL data that Sqlite doesn't recognize
        next if line.include?( 'KEY "' )
        next if line.include?( 'UNIQUE KEY ' )
        next if line.include?( 'PRIMARY KEY ' )
        
        # Replace the MySQL terms to Sqlite-friendly terms
        line.gsub!( /unsigned /, '' )
        line.gsub!( /auto_increment/, ' primary key' )
        line.gsub!( /smallint\([0-9]*\)/, 'integer' )
        line.gsub!( /tinyint\([0-9]*\)/, 'integer' )
        line.gsub!( /int\([0-9]*\)/, 'integer' )
        line.gsub!( /character set [^ ]*/, '' )
        line.gsub!( /enum\([^)]*\)/, 'varchar(255)' )
        line.gsub!( /on update [^,]*/, '' )
        
        # Replace other syntactic differences
        line.gsub!( /\`/, '"' )
        line.gsub!( /"/, '' )
        line.gsub!( /\\'/, '\'\'' )
       
        arr << line
      end 
    end
    
    full = arr.join( '' )
    full.gsub!( /,\n\);/, "\);\n" )
    
    puts "Writing out to: #{@output_file}"
    File.open( @output_file, 'w') { |f| f.write( full ) }
    
    puts "Pushing to Sqlite"
    
  end
end


# ------------------------------ Main ------------------------------ #


if __FILE__ == $0
  # Need at least one parameter passed in as the name of the database to extract data from
  if ( ARGV.length == 0 )
    puts "Usage: $0 <database name> $1 <database user> $2 <database password>"
    exit 0
  end

  conv = MySQL2SqliteConverter.new( ARGV[0], ARGV[1], ARGV[2] )

  # If an output file already exists by this name, warn the user and loop to give them a chance to kill this script
  # If they don't kill the script, remove the file
  conv.handle_existing_file()
  conv.mysql_to_sqlite()
  
  exit 0
end
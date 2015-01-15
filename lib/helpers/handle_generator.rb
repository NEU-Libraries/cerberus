module HandleGenerator

  def make_handle(url)
    client                   = Mysql2::Client.new(:host => "#{ENV["HANDLE_HOST"]}", :username => "#{ENV["HANDLE_USERNAME"]}", :password => "#{ENV["HANDLE_PASSWORD"]}", :database => "#{ENV["HANDLE_DATABASE"]}")
    uts                      = Time.now.to_i
    caldate                  = Date.today.strftime("%Y-%m-%d")
    handleInt                = client.query("SELECT max(right(handle,8)) + 1 FROM handles").first.first[1].to_i
    handleForDB              = "2047/D#{handleInt}"

    client.query("INSERT INTO handles(handle, idx, type, data, ttl_type, ttl, timestamp, admin_read, admin_write, pub_read, pub_write)values('#{handleForDB}',1,'URL','#{url}',0,86400,'#{uts}',1,1,1,0)");
    client.query("INSERT INTO handles(handle, idx, type, data, ttl_type, ttl, timestamp, admin_read, admin_write, pub_read, pub_write)values('#{handleForDB}',100,'HS_ADMIN','ADMIN 300:110011111111:0.NA/2047',0,86400,'#{uts}',1,1,0,0)");
    client.query("INSERT INTO handles(handle, idx, type, data, ttl_type, ttl, timestamp, admin_read, admin_write, pub_read, pub_write)values('#{handleForDB}',300,'HS_SECKEY','UTF8',0,86400,'#{uts}',1,1,0,0)");
    # The 22 refers to the cerberus admin user in the members table
    client.query("INSERT INTO transactions(transaction, member, handle, URL, date) values('CREATE','22','#{handleForDB}','#{url}','#{caldate}')");
    return handleInt;
  end

end

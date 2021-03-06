$: << 'external'
load_assembly 'DolphinDeploy.IIS.IIS6'
load_assembly 'System.DirectoryServices'
include DolphinDeploy::IIS::IIS6
include System::DirectoryServices
    
class IIS6  
  def deploy(server, location, deployment)
    unless apppool_exists?(server, deployment)
      create_app_pool(server, deployment.site_name) #Server is only so we can pull out correct path to deploy too
    end
    
    if(website_exists?(server, deployment))
      update_website_path(server, location, deployment)
    else
      create_website(server, location, deployment)
    end
  end
  
  def website_exists?(server, deployment)
    website = WebsiteController.new
    website.server = server
    website.name = deployment.site_name
    
    return website.exists
  end
  
  def apppool_exists?(server, deployment)
    app_pool = AppPoolController.new
    app_pool.server = server
    app_pool.name = get_app_pool_name(deployment.site_name)
    
    return app_pool.exists
  end
  
  def set_extra_header(server, header, deployment)
    site = get_website(server, deployment)
    
    header.each do |h|
      existing_headers = get_existing_headers(site)
      header_arg = ""
      
      existing_headers.each {|e| header_arg << "\"#{e}\" "}
      
      ip = deployment.get_deploy_to_location(server)[0].ipaddress
      
      cmd = "cscript /nologo external\\adsutil.vbs set w3svc/#{site.name}/ServerBindings \"#{ip}:#{h}\" #{header_arg}"      
      `#{cmd}`
    end
  end
  
  def create_virtual_directory(name, path, deployment)
    site = get_website('localhost', deployment)
    cmd = "cscript /nologo external\\adsutil.vbs CREATE w3svc/#{site.name}/root/#{name} \"IIsWebVirtualDir\""    
    `#{cmd}`
    
    root_site = get_root_site(site)    
    full_path = File.join(root_site.Properties['Path'][0], path)
    cmd = "cscript /nologo external\\adsutil.vbs  SET w3svc/#{site.name}/root/#{name}/path #{convert_path_to_iis_format(full_path)}"    
    `#{cmd}`

		cmd = "cscript /nologo external\\adsutil.vbs  SET w3svc/#{site.name}/root/#{name}/AppFriendlyName #{name}"    
    `#{cmd}`

		
		cmd = "cscript /nologo external\\adsutil.vbs  SET w3svc/#{site.name}/root/#{name}/AppRoot /LM/W3SVC/#{site.name}/root/#{name}"    
    `#{cmd}`
		
		cmd = "cscript /nologo external\\adsutil.vbs  SET w3svc/#{site.name}/root/#{name}/AppIsolated 2"    
    `#{cmd}`
		
		cmd = "cscript /nologo external\\adsutil.vbs  SET w3svc/#{site.name}/root/#{name}/DirBrowseFlags 1073741886"    
    `#{cmd}`
		
		cmd = "cscript /nologo external\\adsutil.vbs  SET w3svc/#{site.name}/root/#{name}/AccessFlags 513"    
    `#{cmd}`
#		root_site.Properties['AppRoot'][0] = "LM/W3SVC/#{site.name}/root/#{name}"
#		root_site.Properties['AppIsolated'][0] = 2
#		root_site.Properties['DirBrowseFlags'][0] = 1073741886
#		root_site.Properties['AccessFlags'][0] = 513
  end
  
  def execute_admin(type, cmd, deployment)
    site = get_website('localhost', deployment)
    cmd = "cscript /nologo external\\adsutil.vbs #{type.to_s} w3svc/#{site.name}/#{cmd}"      
    `#{cmd}`
  end
    
  private
  
  def get_existing_headers(site)
    cmd = "cscript /nologo external\\adsutil.vbs get w3svc/#{site.name}/ServerBindings"
    result = `#{cmd}`
    headers = result.to_a[1..-1].join
    
    headers = clean_output(headers)
    
    return headers
  end
    
  def create_app_pool(server, name)
    app_pool = AppPoolController.new
    app_pool.server = server  # Always executed on the local box
    app_pool.name = get_app_pool_name(name)
    app_pool.create
  end
  
  def update_website_path(server, location, deployment)  
    site = get_website(server, deployment)    
    
    root_site = get_root_site(site)    
    root_site.Properties['Path'][0] = convert_path_to_iis_format(location)
    root_site.commit_changes()
  end
  
  def get_website(server, deployment)
    website = WebsiteController.new
    website.name = deployment.site_name
    website.server = server
    website.get_website()
  end
  
  def create_website(server, location, deployment)
    website = WebsiteController.new
    website.name = deployment.site_name
    website.app_pool = get_app_pool_name(deployment.site_name)
    website.home_directory = convert_path_to_iis_format(location)
    website.port = deployment.port
    website.IpAddress =  deployment.get_deploy_to_location(server)[0].ipaddress
    website.host_header = deployment.host
    website.server = server
        
    website.create
    website.start
    
    set_isapi_filter(deployment) 
  end
  
  def set_isapi_filter(deployment)
    execute_admin(:set, "ScriptMaps \"*,C:\\windows\\Microsoft.NET\\Framework\\v2.0.50727\\aspnet_isapi.dll,1\"", deployment)
  end
    
  def get_app_pool_name(name)
    "#{name}_AppPool"
  end
  
  def convert_path_to_iis_format(path)
    path.gsub('/','\\').to_clr_string
  end
  
  def get_root_site(site)
    path = "IIS://localhost/w3svc/#{site.name}/ROOT"
    DirectoryEntry.new(path.to_clr_string)
  end
  
  def clean_output(output)
    result = []
    
    output.each do |o|
      result << o.strip.gsub("\n", "")
    end
    
    return result
  end
end

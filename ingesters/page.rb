require_relative 'common.rb'

def ingest_page(project_id, web_application_id, source_plugin, path, content_length, status, redirect)
  db_web_application = WebApplication.find(id: web_application_id)

  path = path.strip

  puts "ingesting page: #{path} status: #{status} CL: #{content_length}"

  db_page = Page.find_or_initialize_by(
    web_application_id: web_application_id,
    path: path, 
  )

  if db_page.new_record?
    checkTrigger(
      project_id,
      "new-path",
      [
        ["%fullurl%", db_web_application.full_url], # hopefully hosts are ingested before the service
      ], [
        ["path", path],
        ["status", status],
        ["redirect", redirect],
        ["content_length", content_length]
      ]
    )
  end

  db_path.update_attributes!(
    content_length: content_length,
    status: status,
    redirect: redirect
  )

  db_path.save!

  return db_path
end
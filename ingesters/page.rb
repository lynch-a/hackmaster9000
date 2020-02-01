require_relative 'common.rb'

def ingest_page(project_id, web_application_id, source_plugin, path, content_length, status, redirect)
  puts "ingesting page: #{path} status: #{status} CL: #{content_length}"

  db_web_application = WebApplication.where(id: web_application_id).first
  path = path.strip

  db_page = Page.find_or_initialize_by(
    web_application_id: web_application_id,
    path: path, 
  )

  if db_page.new_record?
    checkTrigger(
      project_id,
      "new-path",
      [
        ["%full_url%", db_page.full_url]
      ], [
        ["path", path],
        ["status", status],
        ["redirect", redirect],
        ["contentlength", content_length]
      ]
    )
  end

  db_page.update_attributes!(
    content_length: content_length,
    status: status,
    redirect: redirect
  )

  db_page.save!

  return db_page
end

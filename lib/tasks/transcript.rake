namespace :transcript do
  desc "Import TRANSCRIPT.md for a user: bin/rails 'transcript:import[path/to/TRANSCRIPT.md,email]'"
  task :import, [ :path, :email ] => :environment do |_, args|
    user = User.find_by!(email_address: args.fetch(:email))
    import = TranscriptImport.call(File.read(args.fetch(:path)), user: user)
    puts "Imported Day #{import.snapshot_attrs[:current_day]} and #{import.courses.size} courses for #{user.email_address}."
  end
end

let () = 
  Logs.set_reporter (Logs.format_reporter ());
  Logs.err (fun m -> m "NO CARRIER")

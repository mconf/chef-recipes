name "monitoring"
description "Monitoring Server"
run_list(
    "role[mconf-server]",
    "recipe[nsca::server]",
    "recipe[nagios::client]",
    "recipe[nagios::server]",
    "recipe[mconf-monitor::json_interface]",
    "recipe[mconf-monitor::nagios_plugins]",
    "recipe[nagiosgraph]",
    "recipe[postfix]",
    "recipe[postfix::sasl_auth]"
)
override_attributes(
    "apache" => {
        "listen_ports" => ["8080"]
    }
)
default_attributes(
    "nagios" => {
        "monitor_chef_nodes" => true,
        "enable_ssl" => true,
        "https" => true,
        "http_port" => 8080,
        "sysadmin_email" => "[your@email.com]",
        "server" => {
            "install_method" => "source",
            "service_name" => "nagios",
            "web_server" => "apache",
            "redirect_root" => true
        },
        "client" => {
            "install_method" => "source"
        },
        "server_auth_method" => "htauth",
        "notifications_enabled" => 1,
        "interval_length" => 1,
        "process_perf_data" => true,
        "default_host" => {
            "check_interval" => 300, # in seconds
            "retry_interval" => 60, # in seconds
            "max_check_attempts" => 10,
            "notification_interval" => 0, # in seconds
            "perfdata_command" => "process_host_perfdata_for_nagiosgraph"
        },
        "default_service" => {
            "check_interval" => 300, # in seconds
            "retry_interval" => 60, # in seconds
            "notification_interval" => 0, # in seconds
            "perfdata_command" => "process_service_perfdata_for_nagiosgraph"
        },
        "host_name_attribute" => "fqdn",
        "log_external_commands" => false,
        "log_passive_checks" => false
    },
    "postfix" => {
        "smtp_sasl_auth_enable" => "yes",
        "smtp_tls_cafile" => "/etc/ssl/certs/ca-certificates.crt",
    }
)

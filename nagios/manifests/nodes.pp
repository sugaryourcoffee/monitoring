node "nagios" {
  include apache2
  include nagios::server
}

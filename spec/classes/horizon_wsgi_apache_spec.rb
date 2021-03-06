require 'spec_helper'

describe 'horizon::wsgi::apache' do

  let :params do
    { :fqdn           => '*',
      :servername     => 'some.host.tld',
      :wsgi_processes => '3',
      :wsgi_threads   => '10',
    }
  end

  let :pre_condition do
    "include apache\n" +
    "class { 'horizon': secret_key => 's3cr3t', configure_apache => false }"
  end

  let :fixtures_path do
    File.expand_path(File.join(__FILE__, '..', '..', 'fixtures'))
  end

  shared_examples_for 'apache for horizon' do

    context 'with default parameters' do
      it 'configures apache' do
        is_expected.to contain_class('horizon::params')
        is_expected.to contain_class('apache')
        is_expected.to contain_class('apache::mod::wsgi')
        is_expected.to contain_service('httpd').with_name(platforms_params[:http_service])
        is_expected.to contain_package('httpd').with_name(platforms_params[:http_service])
        is_expected.to contain_file(platforms_params[:httpd_config_file])
        is_expected.to contain_package('horizon').with_ensure('present')
        is_expected.to contain_apache__vhost('horizon_vhost').with(
          'servername'           => 'some.host.tld',
          'access_log_file'      => 'horizon_access.log',
          'error_log_file'       => 'horizon_error.log',
          'priority'             => '15',
          'serveraliases'        => ['*'],
          'docroot'              => '/var/www/',
          'ssl'                  => 'false',
          'port'                 => '80',
          'redirectmatch_status' => 'permanent',
          'redirectmatch_regexp' => '^/$',
          'redirectmatch_dest'   => platforms_params[:root_url],
          'wsgi_script_aliases'  => { platforms_params[:root_url] => '/usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi' },
          'wsgi_process_group'   => platforms_params[:wsgi_group],
          'wsgi_daemon_process'  => platforms_params[:wsgi_group],
          'wsgi_daemon_process_options' => { 'processes' => params[:wsgi_processes], 'threads' => params[:wsgi_threads], 'user' => platforms_params[:unix_user], 'group' => platforms_params[:unix_group] }
         )
      end
    end

    context 'with overriden parameters' do
      before do
        params.merge!({
          :priority      => '10',
          :redirect_type => 'temp',
        })
      end

      it 'configures apache' do
        is_expected.to contain_class('horizon::params')
        is_expected.to contain_class('apache')
        is_expected.to contain_class('apache::mod::wsgi')
        is_expected.to contain_service('httpd').with_name(platforms_params[:http_service])
        is_expected.to contain_package('httpd').with_name(platforms_params[:http_service])
        is_expected.to contain_file(platforms_params[:httpd_config_file])
        is_expected.to contain_package('horizon').with_ensure('present')
        is_expected.to contain_apache__vhost('horizon_vhost').with(
          'servername'           => 'some.host.tld',
          'access_log_file'      => 'horizon_access.log',
          'error_log_file'       => 'horizon_error.log',
          'priority'             => params[:priority],
          'serveraliases'        => ['*'],
          'docroot'              => '/var/www/',
          'ssl'                  => 'false',
          'port'                 => '80',
          'redirectmatch_status' => 'temp',
          'redirectmatch_regexp' => '^/$',
          'redirectmatch_dest'   => platforms_params[:root_url],
          'wsgi_script_aliases'  => { platforms_params[:root_url] => '/usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi' },
          'wsgi_process_group'   => platforms_params[:wsgi_group],
          'wsgi_daemon_process'  => platforms_params[:wsgi_group],
          'wsgi_daemon_process_options' => { 'processes' => params[:wsgi_processes], 'threads' => params[:wsgi_threads], 'user' => platforms_params[:unix_user], 'group' => platforms_params[:unix_group] }
         )
      end
    end

    context 'with ssl enabled' do
      before do
        params.merge!({
          :listen_ssl   => true,
          :ssl_redirect => true,
          :horizon_cert => '/etc/pki/tls/certs/httpd.crt',
          :horizon_key  => '/etc/pki/tls/private/httpd.key',
          :horizon_ca   => '/etc/pki/tls/certs/ca.crt',
        })
      end

      context 'with required parameters' do
        it 'configures apache for SSL' do
          is_expected.to contain_class('apache::mod::ssl')
        end
        it { is_expected.to contain_apache__vhost('horizon_ssl_vhost').with(
          'servername'             => 'some.host.tld',
          'access_log_file'        => 'horizon_ssl_access.log',
          'error_log_file'         => 'horizon_ssl_error.log',
          'priority'               => '15',
          'serveraliases'          => ['*'],
          'docroot'                => '/var/www/',
          'ssl'                    => 'true',
          'port'                   => '443',
          'ssl_cert'               => '/etc/pki/tls/certs/httpd.crt',
          'ssl_key'                => '/etc/pki/tls/private/httpd.key',
          'ssl_ca'                 => '/etc/pki/tls/certs/ca.crt',
          'redirectmatch_status'   => 'permanent',
          'redirectmatch_regexp'   => '^/$',
          'redirectmatch_dest'     => platforms_params[:root_url],
          'wsgi_process_group'     => 'horizon-ssl',
          'wsgi_daemon_process'    => 'horizon-ssl',
          'wsgi_script_aliases'  => { platforms_params[:root_url] => '/usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi' },
        )}

        it { is_expected.to contain_apache__vhost('horizon_vhost').with(
          'servername'           => 'some.host.tld',
          'access_log_file'      => 'horizon_access.log',
          'error_log_file'       => 'horizon_error.log',
          'priority'             => '15',
          'serveraliases'        => ['*'],
          'docroot'              => '/var/www/',
          'ssl'                  => 'false',
          'port'                 => '80',
          'redirectmatch_status' => 'permanent',
          'redirectmatch_regexp' => '(.*)',
          'redirectmatch_dest'   => 'https://some.host.tld',
          'wsgi_process_group'   => platforms_params[:wsgi_group],
          'wsgi_daemon_process'  => platforms_params[:wsgi_group],
          'wsgi_script_aliases'  => { platforms_params[:root_url] => '/usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi' },
        )}
      end

      context 'without required parameters' do

        context 'without horizon_ca parameter' do
          before { params.delete(:horizon_ca) }
          it_raises 'a Puppet::Error', /The horizon_ca parameter is required when listen_ssl is true/
        end

        context 'without horizon_cert parameter' do
          before { params.delete(:horizon_cert) }
          it_raises 'a Puppet::Error', /The horizon_cert parameter is required when listen_ssl is true/
        end

        context 'without horizon_key parameter' do
          before { params.delete(:horizon_key) }
          it_raises 'a Puppet::Error', /The horizon_key parameter is required when listen_ssl is true/
        end
      end

      context 'with extra parameters' do
        before do
          params.merge!({
            :extra_params  => {
              'add_listen' => false,
              'docroot' => '/tmp'
            },
          })
        end

        it 'configures apache' do
          is_expected.to contain_apache__vhost('horizon_vhost').with(
            'add_listen' => false,
            'docroot'    => '/tmp'
          )
        end

      end

      context 'with root_url set to /' do
        before do
          params.merge!({
            :root_url => '/',
          })
        end

        it 'should not configure redirectmatch' do
          is_expected.to_not contain_apache__vhost('horizon_vhost').with(
            'redirectmatch_regexp' => '^/$',
            'redirectmatch_dest'   => '/'
          )
          is_expected.to_not contain_apache__vhost('horizon_ssl_vhost').with(
            'redirectmatch_regexp' => '^/$',
            'redirectmatch_dest'   => '/'
          )
        end
      end


    end
  end

  shared_examples_for 'apache for horizon on RedHat platforms' do
    it {
      is_expected.to contain_class('apache::mod::wsgi').with(:wsgi_socket_prefix => '/var/run/wsgi')
    }
    it 'configures webroot alias' do
      if (Gem::Version.new(Puppet.version) >= Gem::Version.new('4.0'))
        is_expected.to contain_apache__vhost('horizon_vhost').with(
          'aliases' => [{'alias' => '/dashboard/static', 'path' => '/usr/share/openstack-dashboard/static'}],
        )
      else
        is_expected.to contain_apache__vhost('horizon_vhost').with(
          'aliases' => [['alias', '/dashboard/static'], ['path', '/usr/share/openstack-dashboard/static']],
        )
      end
    end
  end

  shared_examples_for 'apache for horizon on Debian platforms' do
    it 'configures webroot alias' do
      if (Gem::Version.new(Puppet.version) >= Gem::Version.new('4.0'))
        is_expected.to contain_apache__vhost('horizon_vhost').with(
          'aliases' => [{'alias' => '/horizon/static', 'path' => '/usr/share/openstack-dashboard/static'}],
        )
      else
        is_expected.to contain_apache__vhost('horizon_vhost').with(
          'aliases' => [['alias', '/horizon/static'], ['path', '/usr/share/openstack-dashboard/static']],
        )
      end
    end
  end


  on_supported_os({
    :supported_os   => OSDefaults.get_supported_os
  }).each do |os,facts|
    context "on #{os}" do
      let (:facts) do
        if facts[:operatingsystem] == 'Debian'
          facts.merge!({:os_package_type => 'debian'})
        end

        facts.merge!(OSDefaults.get_facts({
          :fqdn           => 'some.host.tld',
          :concat_basedir => '/var/lib/puppet/concat'
        }))
      end

      let(:platforms_params) do
        case facts[:osfamily]
        when 'Debian'
          case facts[:operatingsystem]
          when 'Debian'
            { :http_service      => 'apache2',
              :httpd_config_file => '/etc/apache2/sites-available/openstack-dashboard-alias-only.conf',
              :root_url          => '/horizon',
              :apache_user       => 'www-data',
              :apache_group      => 'www-data',
              :wsgi_user         => 'horizon',
              :wsgi_group        => 'horizon',
              :unix_user         => 'horizon',
              :unix_group        => 'horizon' }
          when 'Ubuntu'
            { :http_service      => 'apache2',
              :httpd_config_file => '/etc/apache2/conf-available/openstack-dashboard.conf',
              :root_url          => '/horizon',
              :apache_user       => 'www-data',
              :apache_group      => 'www-data',
              :wsgi_user         => 'horizon',
              :wsgi_group        => 'horizon',
              :unix_user         => 'horizon',
              :unix_group        => 'horizon' }
          end
        when 'RedHat'
          { :http_service      => 'httpd',
            :httpd_config_file => '/etc/httpd/conf.d/openstack-dashboard.conf',
            :root_url          => '/dashboard',
            :apache_user       => 'apache',
            :apache_group      => 'apache',
            :wsgi_user         => 'apache',
            :wsgi_group        => 'apache',
            :unix_user         => 'apache',
            :unix_group        => 'apache' }
        end
      end

      it_behaves_like 'apache for horizon'
      it_behaves_like "apache for horizon on #{facts[:osfamily]} platforms"
    end
  end

end

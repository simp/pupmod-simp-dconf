require 'spec_helper_acceptance'

test_name 'dconf class'

describe 'dconf class' do
  let(:manifest) {
    <<-EOS
      include '::dconf'

      dconf::profile { 'test':
        entries => {
          'user' => {
            'type' => 'user',
            'order' => 1
          },
          'system' => {
            'type' => 'system',
            'order' => 10
          }
        }
      }

      dconf::settings { 'test settings':
        profile => 'test',
        settings_hash => {
          'org/gnome/desktop/lockdown' => {
            'disable-command-line' => {
              'value' => true
            },
          },
          'org/gnome/desktop/screensaver' => {
            'lock-delay' => {
              'value' => true,
              'lock'  => true
            }
          }
        }
      }
    EOS
  }

  hosts.each do |host|
    context "on #{host}" do
      # This is so that we actually have something to set
      it 'should have gsettings-desktop-schemas installed' do
        install_package(host, 'gsettings-desktop-schemas')
      end

      it 'should work with no errors' do
         apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, manifest, {:catch_changes => true})
      end

      it 'should have dconf installed' do
        host.check_for_command('dconf').should be true
      end
    end
  end
end

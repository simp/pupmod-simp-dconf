require 'spec_helper_acceptance'

test_name 'dconf class'

describe 'dconf class' do
  let(:manifest) do
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
  end

  hosts.each do |host|
    context "on #{host}" do
      # Exercise noop from a clean (uninstalled) state: on a fresh node the Sicura
      # console previews the module with `puppet apply --noop`, which must not error
      # even though nothing dconf manages exists yet. Real idempotence is covered
      # by the applies below. A post-convergence noop check is deliberately omitted:
      # `puppet apply --noop --detailed-exitcodes` always exits 0, so it could never
      # fail and would test nothing.
      context 'in noop mode from a clean state' do
        # Setup, not an assertion: as before(:context) a failure errors this context
        # rather than aborting the whole suite under .rspec's --fail-fast. `puppet
        # resource` exits 0 whether it removes the package or finds it already absent
        # (no --detailed-exitcodes), so no acceptable_exit_codes override is needed.
        before(:context) do
          on(host, 'puppet resource package dconf ensure=absent')
        end

        it 'applies without errors in noop mode' do
          apply_manifest_on(host, manifest, catch_failures: true, noop: true)
        end
      end

      # This is so that we actually have something to set
      it 'has gsettings-desktop-schemas installed' do
        install_package(host, 'gsettings-desktop-schemas')
      end

      it 'works with no errors' do
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, { catch_changes: true })
      end

      it 'has dconf installed' do
        result = on(host, 'rpm -q dconf', accept_all_exit_codes: true)
        expect(result.exit_code).to eq(0), "Expected package 'dconf' to be installed"
      end
    end
  end
end

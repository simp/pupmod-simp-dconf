# frozen_string_literal: true

require 'spec_helper'
require 'yaml'

# Tests the `simp:defaults` Sicura Compliance Engine profile end to end: with
# `compliance_engine::enforcement: [simp:defaults]` set in Hiera, the otherwise
# no-op `include dconf` must reproduce the configuration the module managed by
# default before the 3.0.0 blast-radius refactor.
#
# The "bare include is safe" regression specs live in init_spec.rb and are
# intentionally left untouched -- they guard the safe default when the profile
# is NOT enforced.
PRE_REFACTOR_USER_PROFILE = {
  'user'   => { 'type' => 'user',   'order' => 1 },
  'local'  => { 'type' => 'system', 'order' => 20 },
  'site'   => { 'type' => 'system', 'order' => 30 },
  'distro' => { 'type' => 'system', 'order' => 40 },
}.freeze

TEST_SETTINGS = <<~EOM
  dconf::settings { 'test settings':
    profile       => 'gdm',
    settings_hash => {
      'org/gnome/desktop/screensaver' => {
        'lock-delay' => { 'value' => 0 },
      },
    },
  }
EOM

describe 'dconf' do
  def self.profile_dir
    File.expand_path('../../SIMP/compliance_profiles', __dir__)
  end

  # --------------------------------------------------------------------------
  # Profile/check data integrity (no catalog compilation)
  # --------------------------------------------------------------------------
  context 'profile data' do
    let(:checks) { YAML.safe_load_file(File.join(self.class.profile_dir, 'checks.yaml'))['checks'] }
    let(:profile) { YAML.safe_load_file(File.join(self.class.profile_dir, 'profile-simp_defaults.yaml'))['profiles']['simp:defaults'] }

    it 'lists exactly the defined checks (no orphans, none missing)' do
      expect(profile['checks'].keys.sort).to eq(checks.keys.sort)
    end

    it 'only manages dconf:: parameters' do
      params = checks.values.map { |c| c['settings']['parameter'] }
      expect(params).to all(start_with('dconf::'))
    end
  end

  # --------------------------------------------------------------------------
  # Enforced, no overrides: reproduces the pre-refactor catalog.
  # --------------------------------------------------------------------------
  context 'when enforcing simp:defaults' do
    let(:hiera_config) do
      File.expand_path('../fixtures/hieradata/hiera_compliance_engine.yaml', __dir__)
    end

    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) { os_facts.merge(custom_hiera: 'simp_defaults_enforced') }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('dconf') }

        it 'restores the pre-3.0.0 default user profile' do
          is_expected.to create_dconf__profile('Defaults').with_target('user')
          is_expected.to create_dconf__profile('Defaults').with_entries(PRE_REFACTOR_USER_PROFILE)
          is_expected.to create_concat('/etc/dconf/profile/user').with_order('numeric')
        end

        { 'user' => ['user-db:user', 1],
          'local' => ['system-db:local', 20],
          'site' => ['system-db:site', 30],
          'distro' => ['system-db:distro', 40] }.each do |db, (content, order)|
          it "writes the #{db} database entry" do
            is_expected.to create_concat__fragment("dconf::profile::user::#{db}")
              .with(
                target: '/etc/dconf/profile/user',
                content: "#{content}\n",
                order: order,
              )
          end
        end

        context 'with a dconf::settings resource declared' do
          let(:pre_condition) { TEST_SETTINGS }

          it { is_expected.to compile.with_all_deps }

          it 'restores the pre-3.0.0 purge of unmanaged files (tidy)' do
            is_expected.to create_file('/etc/dconf/db/gdm.d').with_purge(true)
            is_expected.to create_file('/etc/dconf/db/gdm.d/locks').with_purge(true)
          end
        end
      end
    end
  end

  # --------------------------------------------------------------------------
  # Enforced + explicit site override: site Hiera outranks the profile, so
  # sites can keep the profile but opt out of individual (destructive)
  # behaviors.
  # --------------------------------------------------------------------------
  context 'when enforcing simp:defaults with an explicit dconf::tidy override' do
    let(:hiera_config) do
      File.expand_path('../fixtures/hieradata/hiera_compliance_engine.yaml', __dir__)
    end
    let(:pre_condition) { TEST_SETTINGS }

    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) { os_facts.merge(custom_hiera: 'simp_defaults_with_override') }

        it { is_expected.to compile.with_all_deps }

        it 'still restores the default user profile' do
          is_expected.to create_dconf__profile('Defaults').with_entries(PRE_REFACTOR_USER_PROFILE)
        end

        it 'honors the site override over the profile value' do
          is_expected.to create_file('/etc/dconf/db/gdm.d').with_purge(false)
          is_expected.to create_file('/etc/dconf/db/gdm.d/locks').with_purge(false)
        end
      end
    end
  end
end

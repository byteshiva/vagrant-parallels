module VagrantPlugins
  module Parallels
    module Action
      class Export
        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new('vagrant_parallels::action::export')
        end

        def call(env)
          if env[:machine].state.id != :stopped
            raise Vagrant::Errors::VMPowerOffToPackage
          end

          clone(env)
          compact(env)
          unregister_vm(env)

          @app.call(env)
        end

        def recover(env)
          unregister_vm(env)
        end

        private

        def box_vm_name(env)
          # Use configured name if it is specified, or generate the new one
          name = env[:machine].provider_config.name
          if !name
            name = "#{env[:root_path].basename.to_s}_#{env[:machine].name}"
            name.gsub!(/[^-a-z0-9_]/i, '')
          end

          vm_name = "#{name}_box"

          # Ensure that the name is not in use
          ind = 0
          while env[:machine].provider.driver.read_vms.has_key?(vm_name)
            ind += 1
            vm_name = "#{name}_box_#{ind}"
          end

          vm_name
        end

        def clone(env)
          env[:ui].info I18n.t('vagrant.actions.vm.export.exporting')

          options = {
            dst: env['export.temp_dir'].to_s
          }

          env[:package_box_id] = env[:machine].provider.driver.clone_vm(
            env[:machine].id, options) do |progress|
            env[:ui].clear_line
            env[:ui].report_progress(progress, 100, false)

            # If we got interrupted, then rise an exception and 'recover'
            # will be called to cleanup.
            raise Vagrant::Errors::VagrantInterrupt if env[:interrupted]
          end

          # Set the box VM name
          name = box_vm_name(env)
          env[:machine].provider.driver.set_name(env[:package_box_id], name)

          # Clear the line a final time so the next data can appear
          # alone on the line.
          env[:ui].clear_line
        end

        def compact(env)
          env[:ui].info I18n.t('vagrant_parallels.actions.vm.export.compacting')
          env[:machine].provider.driver.compact(env[:package_box_id]) do |progress|
            env[:ui].clear_line
            env[:ui].report_progress(progress, 100, false)
          end

          # Clear the line a final time so the next data can appear
          # alone on the line.
          env[:ui].clear_line
        end

        def unregister_vm(env)
          return if !env[:package_box_id]
          @logger.info("Unregister the box VM: '#{env[:package_box_id]}'")
          env[:machine].provider.driver.unregister(env[:package_box_id])
        end
      end
    end
  end
end

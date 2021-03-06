module Dapp
  module Dimg
    module Build
      module Stage
        class ArtifactDefault < ArtifactBase
          protected

          def apply_artifact(artifact, image)
            return if dimg.dapp.dry_run?

            artifact_name = artifact[:name]
            artifact_dimg = artifact[:dimg]
            cwd = artifact[:options][:cwd]
            include_paths = artifact[:options][:include_paths]
            exclude_paths = artifact[:options][:exclude_paths]
            owner = artifact[:options][:owner]
            group = artifact[:options][:group]
            to = artifact[:options][:to]

            command = safe_cp(cwd, artifact_dimg.container_tmp_path(artifact_name).to_s, Process.uid, Process.gid, include_paths, exclude_paths)
            run_artifact_dimg(artifact_dimg, artifact_name, command)

            command = safe_cp(dimg.container_tmp_path('artifact', artifact_name).to_s, to, owner, group, include_paths, exclude_paths)
            image.add_command command
            image.add_volume "#{dimg.tmp_path('artifact', artifact_name)}:#{dimg.container_tmp_path('artifact', artifact_name)}:ro"
          end
          # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

          private

          # rubocop:disable Metrics/ParameterLists
          def safe_cp(from, to, owner, group, include_paths = [], exclude_paths = [])
            ''.tap do |cmd|
              cmd << dimg.dapp.rsync_bin
              cmd << ' --archive --links'
              cmd << " --chown=#{owner}:#{group}" if owner or group

              if include_paths.any?
                # Если указали include_paths — это означает, что надо копировать
                # только указанные пути. Поэтому exclude_paths в приоритете, т.к. в данном режиме
                # exclude_paths может относится только к путям, указанным в include_paths.
                # При этом случай, когда в include_paths указали более специальный путь, чем в exclude_paths,
                # будет обрабатываться в пользу exclude, этот путь не скопируется.
                exclude_paths.each do |p|
                  cmd << " --filter='-/ #{File.join(from, p)}'"
                end

                include_paths.each do |p|
                  # * На данный момент не знаем директорию или файл имел в виду пользователь,
                  #   поэтому подставляем фильтры для обоих возможных случаев.
                  # * Автоматом подставляем паттерн ** для включения файлов, содержащихся в
                  #   директории, которую пользователь указал в include_paths.
                  cmd << " --filter='+/ #{File.join(from, p)}'"
                  cmd << " --filter='+/ #{File.join(from, p, '**')}'"
                end

                # Все что не подошло по include — исключается
                cmd << " --filter='-/ #{File.join(from, '**')}'"
              else
                exclude_paths.each do |p|
                  cmd << " --filter='-/ #{File.join(from, p)}'"
                end
              end

              # Слэш после from — это инструкция rsync'у для копирования
              # содержимого директории from, а не самой директории.
              cmd << " #{from}/ #{to}"
            end
          end
          # rubocop:enable Metrics/ParameterLists
        end # ArtifactDefault
      end # Stage
    end # Build
  end # Dimg
end # Dapp

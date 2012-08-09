require 'facter'

if File.exists?("/usr/sbin/hpacucli")
  raw_data =  %x{/usr/sbin/hpacucli controller all show config detail}
  raw_data = raw_data.split("\n")
  raw_data.reject!{|x| x =~ /^\s+$/}
  raw_data = raw_data.map do |x|
    x.chomp.strip.squeeze(' ').gsub(' ', '_').gsub(/(\(|\))/, '')
  end

  context_array = []
  pd = 0
  mirror_group = {}

  raw_data.each do |line|
    popped = ''
    id = ''
    case line.downcase
      when /smart_array_.*?_in_slot_[0-9]+(_\(embedded\))*/
        context_array.push "hp_array0"
      when /array:_(.)$/
        id = $1
        while(!popped.match(/array:_(.)$/) && context_array.size > 1)
          popped = context_array.pop
        end
        context_array.push "array#{id}"
      when /logical_drive:_(\d+)/
        id = $1
        while(!popped.match(/logical_drive:_(\d+)/) && context_array.size > 2)
          popped = context_array.pop
        end
        pd = 0
        context_array.push "ld#{id}"
      when /mirror_group_(\d+)/
        id = $1
        while(!popped.match(/mirror_group_(\d+)/) && context_array.size > 3)
              popped = context_array.pop
        end
        mirror_group["mirror_group_#{id}"] = []
        context_array.push "mirror_group_#{id}"
      when /physicaldrive_(\d:\d|\d.:\d:\d)_/
        did = $1
        if context_array.last && context_array.last.match(/mirror_group_(\d+)/)
          mirror_group["mirror_group_#{$1}"] << did
        end
      when /physicaldrive_(\d:\d|\d.:\d:\d)+$/
        pid=$1
        while(!popped.match(/physicaldrive_(\d:\d|\d.:\d:\d)+$/) && context_array.size > 3)
          popped = context_array.pop
        end
        pd += 1 unless popped == ''
       
        mirror_group.each do |k,v|
          if v.include? pid
            context_array.push k
          end
        end
        context_array.push "pd#{pd}"
      else
        if context_array.last && context_array.last.downcase.match(/mirror_group_(\d+)$/)
          key, value = line.split('_', 2)
          context_array.push key
          context_array.pop
        else
          key, value = line.split(':')
        end
        context_array.push key
        value.gsub!('_', '') if value
        factname = context_array.join("_").downcase
        (Facter.add(context_array.join("_").downcase) do setcode do value end end) unless factname == ''
        context_array.pop
      end
    popped = ''
    id = ''
  end
end

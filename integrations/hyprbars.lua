-- OmaUX macOS-style traffic-light controls for Hyprland + hyprbars.
if hl.plugin and hl.plugin.hyprbars and hl.plugin.hyprbars.add_button then
  hl.config({ plugin = { hyprbars = {
    enabled=true, bar_height=28, bar_color="rgba(1b1b26f2)", ["col.text"]="rgba(d8d8e5d9)",
    bar_title_enabled=true, bar_text_size=10, bar_text_weight=500, bar_text_font="Sans",
    bar_text_align="center", bar_buttons_alignment="left", bar_part_of_window=true,
    bar_precedence_over_border=true, bar_padding=8, bar_button_padding=6, icon_on_hover=true,
    inactive_button_color="rgba(767680b8)"
  }}})
  hl.plugin.hyprbars.add_button({bg_color="rgb(ff5f57)",fg_color="rgb(5b1410)",size=12,icon="×",action="/usr/bin/hyprctl dispatch 'hl.dsp.window.close()'"})
  hl.plugin.hyprbars.add_button({bg_color="rgb(febc2e)",fg_color="rgb(654800)",size=12,icon="−",action="omaux-dock-window minimize-active"})
  hl.plugin.hyprbars.add_button({bg_color="rgb(28c840)",fg_color="rgb(07551a)",size=12,icon="+",action="omaux-window-layout maximize"})
end

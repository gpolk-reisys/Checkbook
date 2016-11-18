<?php

/**
 * Add body classes if certain regions have content.
 */
function checkbooknyc_preprocess_html(&$variables) {
  if (!empty($variables['page']['featured'])) {
    $variables['classes_array'][] = 'featured';
  }

  if (!empty($variables['page']['triptych_first'])
    || !empty($variables['page']['triptych_middle'])
    || !empty($variables['page']['triptych_last'])) {
    $variables['classes_array'][] = 'triptych';
  }

  if (!empty($variables['page']['footer_firstcolumn'])
    || !empty($variables['page']['footer_secondcolumn'])
    || !empty($variables['page']['footer_thirdcolumn'])
    || !empty($variables['page']['footer_fourthcolumn'])) {
    $variables['classes_array'][] = 'footer-columns';
  }

    drupal_add_js('https://d3js.org/d3.v3.min.js', 'external');
//    drupal_add_js('https://code.jquery.com/jquery-3.1.1.min.js', 'external');

//  // Add conditional stylesheets for IE
//  drupal_add_css(path_to_theme() . '/css/ie.css', array('group' => CSS_THEME, 'browsers' => array('IE' => 'lte IE 7', '!IE' => FALSE), 'preprocess' => FALSE));
//  drupal_add_css(path_to_theme() . '/css/ie6.css', array('group' => CSS_THEME, 'browsers' => array('IE' => 'IE 6', '!IE' => FALSE), 'preprocess' => FALSE));
}

/**
 * Override or insert variables into the page template for HTML output.
 */
function checkbooknyc_process_html(&$variables) {
  // Hook into color.module.
  if (module_exists('color')) {
    _color_html_alter($variables);
  }
}

/**
 * Override or insert variables into the page template.
 */
function checkbooknyc_process_page(&$variables) {

    
//  // Hook into color.module.
//  if (module_exists('color')) {
//    _color_page_alter($variables);
//  }
//  // Always print the site name and slogan, but if they are toggled off, we'll
//  // just hide them visually.
//  $variables['hide_site_name']   = theme_get_setting('toggle_name') ? FALSE : TRUE;
//  $variables['hide_site_slogan'] = theme_get_setting('toggle_slogan') ? FALSE : TRUE;
//  if ($variables['hide_site_name']) {
//    // If toggle_name is FALSE, the site_name will be empty, so we rebuild it.
//    $variables['site_name'] = filter_xss_admin(variable_get('site_name', 'Drupal'));
//  }
//  if ($variables['hide_site_slogan']) {
//    // If toggle_site_slogan is FALSE, the site_slogan will be empty, so we rebuild it.
//    $variables['site_slogan'] = filter_xss_admin(variable_get('site_slogan', ''));
//  }
//  // Since the title and the shortcut link are both block level elements,
//  // positioning them next to each other is much simpler with a wrapper div.
//  if (!empty($variables['title_suffix']['add_or_remove_shortcut']) && $variables['title']) {
//    // Add a wrapper div using the title_prefix and title_suffix render elements.
//    $variables['title_prefix']['shortcut_wrapper'] = array(
//      '#markup' => '<div class="shortcut-wrapper clearfix">',
//      '#weight' => 100,
//    );
//    $variables['title_suffix']['shortcut_wrapper'] = array(
//      '#markup' => '</div>',
//      '#weight' => -99,
//    );
//    // Make sure the shortcut link is the first item in title_suffix.
//    $variables['title_suffix']['add_or_remove_shortcut']['#weight'] = -100;
//  }
}
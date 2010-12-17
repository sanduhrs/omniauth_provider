<?php
// $Id$

/**
 * Return an array of the modules to be enabled when this profile is installed.
 *
 * @return
 *   An array of modules to enable.
 */
function omniauth_profile_modules() {
  return array(
    // Drupal core
    'menu', 'dblog',
    // Contrib
    'date', 'date_api', 'features','content', 'text',
    'auto_nodetitle', 'jquery_ui', 'date_popup', 'content_profile', 'content_profile_registration',
    // Omniauth
    'omniauth_provider', 'omniauth_provider_initialize', 'omniauth_access',
    'openid_provider', 'openid_provider_ax', 'openid_provider_sso', 'openid_profile',
    'openid_cp_field', 'xrds_simple',
    );
}

/**
 * Return a description of the profile for the initial installation screen.
 *
 * @return
 *   An array with keys 'name' and 'description' describing this profile,
 *   and optional 'language' to override the language selection for
 *   language-specific profiles.
 */
function omniauth_profile_details() {
  return array(
    'name' => 'Omniauth OpenID-Simple-Sign-On',
    'description' => 'Select this profile to enable the Omniauth OpenID-Simple-Sign-On setup.'
  );
}

/**
 * Return a list of tasks that this profile supports.
 *
 * @return
 *   A keyed array of tasks the profile will perform during
 *   the final stage. The keys of the array will be used internally,
 *   while the values will be displayed to the user in the installer
 *   task list.
 */
function omniauth_profile_task_list() {
}

/**
 * Perform any final installation tasks for this profile.
 *
 * The installer goes through the profile-select -> locale-select
 * -> requirements -> database -> profile-install-batch
 * -> locale-initial-batch -> configure -> locale-remaining-batch
 * -> finished -> done tasks, in this order, if you don't implement
 * this function in your profile.
 *
 * If this function is implemented, you can have any number of
 * custom tasks to perform after 'configure', implementing a state
 * machine here to walk the user through those tasks. First time,
 * this function gets called with $task set to 'profile', and you
 * can advance to further tasks by setting $task to your tasks'
 * identifiers, used as array keys in the hook_profile_task_list()
 * above. You must avoid the reserved tasks listed in
 * install_reserved_tasks(). If you implement your custom tasks,
 * this function will get called in every HTTP request (for form
 * processing, printing your information screens and so on) until
 * you advance to the 'profile-finished' task, with which you
 * hand control back to the installer. Each custom page you
 * return needs to provide a way to continue, such as a form
 * submission or a link. You should also set custom page titles.
 *
 * You should define the list of custom tasks you implement by
 * returning an array of them in hook_profile_task_list(), as these
 * show up in the list of tasks on the installer user interface.
 *
 * Remember that the user will be able to reload the pages multiple
 * times, so you might want to use variable_set() and variable_get()
 * to remember your data and control further processing, if $task
 * is insufficient. Should a profile want to display a form here,
 * it can; the form should set '#redirect' to FALSE, and rely on
 * an action in the submit handler, such as variable_set(), to
 * detect submission and proceed to further tasks. See the configuration
 * form handling code in install_tasks() for an example.
 *
 * Important: Any temporary variables should be removed using
 * variable_del() before advancing to the 'profile-finished' phase.
 *
 * @param $task
 *   The current $task of the install system. When hook_profile_tasks()
 *   is first called, this is 'profile'.
 * @param $url
 *   Complete URL to be used for a link or form action on a custom page,
 *   if providing any, to allow the user to proceed with the installation.
 *
 * @return
 *   An optional HTML string to display to the user. Only used if you
 *   modify the $task, otherwise discarded.
 */
function omniauth_profile_tasks(&$task, $url) {

  // Insert default user-defined node types into the database. For a complete
  // list of available node type attributes, refer to the node type API
  // documentation at: http://api.drupal.org/api/HEAD/function/hook_node_info.
  $types = array(
  );

  foreach ($types as $type) {
    $type = (object) _node_type_set_defaults($type);
    node_type_save($type);
  }

  // Set some defaults
  variable_set('openid_profile_map', array(
    'http://axschema.org/namePerson/friendly' => 'name',
    'http://axschema.org/contact/email' => 'mail',
  ));
  variable_set('openid_cp_field_map_profile', array(
    'http://axschema.org/namePerson/prefix' => 'field_name_person_prefix',
    'http://axschema.org/namePerson/first' => 'field_name_person_first',
    'http://axschema.org/namePerson/last' => 'field_name_person_last',
    'http://axschema.org/birthDate' => 'field_birth_date',
    'http://axschema.org/contact/postalCode/home' => 'field_contact_postal_code_home',
    'http://axschema.org/contact/city/home' => 'field_contact_city_home',
  ));
  variable_set('content_profile_use_profile', 1);
  variable_set('content_profile_profile', array(
    'weight' => 0,
    'user_display' => 'full',
    'edit_link' => 0,
    'edit_tab' => 'sub',
    'add_link' => 1,
    'registration_use' => 1,
    'admin_user_create_use' => 1,
    'registration_hide' => array(
      0 => 'title',
    )
  ));
  variable_set('node_options_profile', array(0 => 'status'));
  variable_set('site_frontpage', 'user');
  // Cleanup
  omniauth_cleanup();
}

/**
 * Implementation of hook_form_alter().
 *
 * Allows the profile to alter the site-configuration form. This is
 * called through custom invocation, so $form_state is not populated.
 */
function omniauth_form_alter(&$form, $form_state, $form_id) {
  if ($form_id == 'install_configure') {
    // Set default for site name field.
    $form['site_information']['site_name']['#default_value'] = $_SERVER['SERVER_NAME'];
  }
}

/**
 * Do some cleanup
 */
function omniauth_cleanup() {

  // Rebuild node types
  node_types_rebuild();

  // Rebuild the menu
  menu_rebuild();

  // Clear out caches
  $core = array('cache', 'cache_block', 'cache_filter', 'cache_page');
  $cache_tables = array_merge(module_invoke_all('flush_caches'), $core);
  foreach ($cache_tables as $table) {
    cache_clear_all('*', $table, TRUE);
  }

  // Clear out JS and CSS caches
  drupal_clear_css_cache();
  drupal_clear_js_cache();

  // Clear drupal message queue for non-warning/errors
  drupal_get_messages('status', TRUE);

  // Rebuild node access database - required after OG installation
  node_access_rebuild();

  // Greetings
  watchdog('Omniauth',
    t('Welcome to Omniauth OpenID-Simple-Sign-On brought to you by !ef_link.',
      array(
        '!ef_link' => l('erdfisch', 'http://erdfisch.de'),
      )
    )
  );
}

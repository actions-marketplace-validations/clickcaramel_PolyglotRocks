#!/usr/bin/env bash

languages=(en fr de)
app_name='TestApp'
script='../bin/polyglot'
file_name='Localizable.strings'
other_source='Other.strings'
tenant_token='f233f89a-7868-4e53-854c-9fa60f5b283e'
translations_path="../$app_name/Extra"
api_url='https://api.dev.polyglot.rocks'
api_url=${API_URL:-$api_url}
product_id='test.bash.app'
base_file="$translations_path/en.lproj/$file_name"
initial_data='"Cancel" = "Cancel";
"Saved successfully" = "Saved successfully";
// some comment = 0
"4K" = "4K";
"Loading" = "Loading...";'

cache_root="/tmp"
if [ -n "$GITHUB_HEAD_REF" ]; then
    cache_root="./tmp"
fi

local_env_init() {
    rm -rf "$translations_path"

    for lang in ${languages[@]}; do
        path="$translations_path/$lang.lproj";
        mkdir -p "$path";
        echo "$initial_data" > "$path/$file_name"
        echo "" > "$path/$other_source"
    done

    rm -rf "$cache_root/$product_id"
    echo '"Loading" = "custom-translation";' > "$translations_path/de.lproj/$file_name"
}

clear_db() {
    curl -X DELETE -H "Accept: application/json" -H "Authorization: Bearer $tenant_token" -L "$api_url/products/$1/strings/Cancel" -s >> /dev/null
    curl -X DELETE -H "Accept: application/json" -H "Authorization: Bearer $tenant_token" -L "$api_url/products/$1/strings/Loading" -s >> /dev/null
    curl -X DELETE -H "Accept: application/json" -H "Authorization: Bearer $tenant_token" -L "$api_url/products/$1/strings/Saved successfully" -s >> /dev/null
}

add_manual_translations() {
    curl -X PUT -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $tenant_token" -L "$api_url/products/$product_id/strings/Cancel" -d "{ \"translations\": { \"en\": \"Cancel\", \"de\": \"de-manual-test\", \"fr\": \"fr-manual-test\" } }" -s >> /dev/null
}

setup_suite() {
    clear_db "$product_id"
    local_env_init
}

setup() {
    export PRODUCT_BUNDLE_IDENTIFIER=$product_id
}

test_token_not_specified() {
    assert_equals "`$script | grep 'Tenant token is required as a first argument'`" 'Tenant token is required as a first argument'
}

test_product_id_not_specified() {
    export PRODUCT_BUNDLE_IDENTIFIER=''
    result=`$script $tenant_token -p ../$app_name | grep -v WARN`
    assert_equals "$result" 'Product id is not specified. Use $PRODUCT_BUNDLE_IDENTIFIER for this'
}

test_invalid_tenant_token() {
    assert_equals "`$script 11111 -p ../$app_name | grep 'Invalid tenant token'`" 'Invalid tenant token'
}

test_clear_cache_error() {
    export PRODUCT_BUNDLE_IDENTIFIER=''
    result=`$script --clear-cache | grep -v WARN`
    assert_equals "$result" 'Product id is not specified. Use $PRODUCT_BUNDLE_IDENTIFIER for this'
}

test_clear_cache() {
    add_manual_translations
    output=`$script $tenant_token -p ../$app_name`
    output=`$script --clear-cache`

    cache_path=`find $cache_root/$product_id -name ".last_used_manual_translations" | head -1`
    cache_content=`cat "$cache_path"`
    assert_equals "$cache_content" '{}'
}

test_found_duplicates() {
    base_file_content=`cat $base_file`
    echo '"Loading" = "Loading...";' >> $base_file
    output="`$script $tenant_token -p ../$app_name`"
    is_found_duplicates=`echo "$output" | grep -c 'Found duplicates'`
    assert_equals $is_found_duplicates 1
    echo "$base_file_content" > $base_file
}

test_auto_translation() {
    setup_suite
    output="`$script $tenant_token -p ../$app_name`"
    translation=`grep 'Cancel' $translations_path/de.lproj/$file_name | cut -d '=' -f 2`
    custom_translation=`grep 'Loading' $translations_path/de.lproj/$file_name | cut -d '=' -f 2`
    marked_translation=`grep '4K' $translations_path/fr.lproj/$file_name | cut -d '=' -f 2`
    description=`curl -H "Accept: application/json" -H "Authorization: Bearer $tenant_token" -L "$api_url/products/$product_id/strings/4K" -s | jq -r '.description'`

    assert_equals '"Abbrechen";' $translation
    assert_equals ' "4K"; //' "$marked_translation"
    assert_equals '"custom-translation";' $custom_translation
    assert_equals 'some comment = 0' "$description"
}

test_load_manual_translations() {
    add_manual_translations

    if [ -z "$1" ]; then
        local_env_init
    fi

    output=`$script $tenant_token -p ../$app_name`
    translation=`grep 'Cancel' $translations_path/de.lproj/$file_name | cut -d '=' -f 2`
    assert_equals $translation '"de-manual-test";'
}

test_replace_auto_translations_with_manual() {
    setup_suite
    test_auto_translation
    test_load_manual_translations 'no-clear'
}

test_translations_from_other_file() {
    cp $base_file $translations_path/en.lproj/$other_source
    echo '"Now" = "Now";' >> $translations_path/en.lproj/$other_source

    output=`$script $tenant_token -p ../$app_name -f $other_source`
    translation=`grep 'Now' $translations_path/fr.lproj/$other_source | cut -d '=' -f 2`

    assert_equals ' "Maintenant";' "$translation"
}

test_do_nothing_without_updates() {
    output=`$script $tenant_token -p ../$app_name`
    output=`$script $tenant_token -p ../$app_name`
    output="`$script $tenant_token -p ../$app_name`"
    translation_count=`grep -c 'Loading' $translations_path/de.lproj/$file_name`
    files_without_changes=`echo "$output" | grep -c 'seems to be translated already'`
    assert_equals $files_without_changes 2
    assert_equals $translation_count 1
}

test_add_new_language() {
    rm -rf "$cache_root/$product_id"
    curl -X PUT -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $tenant_token" -L "$api_url/products/$product_id" -d "{ \"languages\": [ \"en\"] }" -s
    path="$translations_path/ru.lproj";
    mkdir -p "$path";
    echo "" > "$path/$file_name"
    output=`$script $tenant_token -p ../$app_name`
    translation=`grep 'Cancel' $path/$file_name | cut -d '=' -f 2`
    assert_equals ' "Отмена";' "$translation"
}

test_translate_equal_strings_when_equal_line_count() {
    clear_db "$product_id"
    # x2 launch for getting manual_translations_changed == false
    output=`$script $tenant_token -p ../$app_name`
    output=`$script $tenant_token -p ../$app_name`

    path="$translations_path/fr.lproj/$file_name";
    echo "$initial_data" | head -4 > $path
    echo '"Loading" = "custom-translation";' >> $path
    output=`$script $tenant_token -p ../$app_name`
    translation=`grep 'Cancel' $path | cut -d '=' -f 2`
    custom_translation=`grep 'Loading' $path | cut -d '=' -f 2`
    assert_equals ' "Annuler";' "$translation"
    assert_equals ' "custom-translation";' "$custom_translation"
}

test_remove_duplicates_from_lang_files() {
    path="$translations_path/fr.lproj/$file_name";
    echo "$initial_data" > $path
    echo '"4K" = "4K";' >> $path
    echo '"4K" = "4K";' >> $path
    output=`$script $tenant_token -p ../$app_name`
    translations_count=`grep -c '4K' $path`
    assert_equals 1 "$translations_count"
}

test_remove_deleted_strings_from_lang_files() {
    path="$translations_path/fr.lproj/$file_name";
    removed_lines='"DELETED" = "deleted str";
"Unused" = "DELETED";'
    echo "$removed_lines" >> $path
    output=`$script $tenant_token -p ../$app_name`
    removed_lines_count=`grep -c "$removed_lines" $path`
    assert_equals 0 $removed_lines_count
}

test_use_complex_comment() {
    path="$translations_path/en.lproj/$file_name";
    NL=$'\n'
    complex_comment='// some|~|text
   //complex "comment!@#$%^&*")
	//  serious: case'
    str='"complex_str" = "complex string";'
    echo "$initial_data${NL}$complex_comment${NL}$str" > $path
    output=`$script $tenant_token -p ../$app_name`
    description=`curl -H "Accept: application/json" -H "Authorization: Bearer $tenant_token" -L "$api_url/products/$product_id/strings/complex_str" -s | jq -r '.description'`
    descr_from_comment=`echo "$complex_comment" | sed -e 's/[ 	]*\/\/[ ]*//g' -e 's/"/\\\"/g'`
    escaped_descr=`echo "$description" | sed -e 's/"/\\\"/g'`

    assert_equals 3 `echo "$escaped_descr" | wc -l`
    assert_equals "$descr_from_comment" "$escaped_descr"
}

jQuery(function () {
    var form = jQuery("#automatic-assignment");
    var addFilterSelect = form.find('select[name=FilterType]');
    var filtersField = form.find('input[name=Filters]');
    var chooserField = form.find('input[name=Chooser]');

    var i = form.find('.filters .sortable-box').length;

    var refreshFiltersField = function () {
        var filters = "";
        form.find('.filters .sortable-box').each(function () {
            filters += jQuery(this).data('prefix') + ',';
        });

        filtersField.val(filters);
    };

    form.find('input.button[name=AddFilter]').click(function (e) {
        e.preventDefault();
        var filter = addFilterSelect.val();
        if (filter) {
            var params = {
                Name: filter,
                i: ++i
            };

            jQuery.ajax({
                url: RT.Config.WebHomePath + "/Helpers/AddFilter",
                data: params,
                success: function (html) {
                    form.find('.filters').append(html);
                    refreshFiltersField();
                    addFilterSelect.val('');
                },
                error: function (xhr, reason) {
                    alert(reason);
                }
            });
        }
        else {
            alert("Please select a filter.");
        }
    });

    form.find('select[name=ChooserType]').change(function (e) {
        e.preventDefault();
        var chooser = jQuery(this).val();
        var params = {
            Name: chooser
        };
        jQuery('.chooser .sortable-box').empty();

        jQuery.ajax({
            url: RT.Config.WebHomePath + "/Helpers/SelectChooser",
            data: params,
            success: function (html) {
                form.find('.chooser .sortable-box').replaceWith(html);
                chooserField.val('Chooser_' + chooser);
            },
            error: function (xhr, reason) {
                alert(reason);
            }
        });
    });
});


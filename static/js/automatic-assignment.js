jQuery(function () {
    var form = jQuery("#automatic-assignment");
    var addFilterSelect = form.find('select[name=FilterType]');
    var filtersField = form.find('input[name=Filters]');
    var chooserField = form.find('input[name=Chooser]');
    var filterContainer = form.find('.filters');
    var chooserContainer = form.find('.chooser');
    var filterList = form.find('.filter-list');
    var addFilterButton = form.find('input.button[name=AddFilter]');

    var i = filterList.find('.sortable-box').length;

    var refreshFiltersField = function () {
        var filters = "";
        filterList.find('.sortable-box').each(function () {
            filters += jQuery(this).data('prefix') + ',';
        });

        filtersField.val(filters);
    };

    addFilterButton.click(function (e) {
        e.preventDefault();
        var filter = addFilterSelect.val();
        if (filter) {
            var params = {
                Name: filter,
                i: ++i
            };

            filterContainer.addClass('adding');
            addFilterSelect.attr('disabled', true);
            addFilterButton.attr('disabled', true);

            jQuery.ajax({
                url: RT.Config.WebHomePath + "/Helpers/AddFilter",
                data: params,
                success: function (html) {
                    jQuery(html).prependTo(filterList).hide().slideDown();
                    refreshFiltersField();
                    filterContainer.removeClass('adding');
                    addFilterSelect.val('').attr('disabled', false);
                    addFilterButton.attr('disabled', false);
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
        var chooserName = jQuery(this).val();
        var params = {
            Name: chooserName
        };

        chooserContainer.addClass('replacing');
        chooserContainer.find('.sortable-box :input').attr('disabled', true);

        jQuery.ajax({
            url: RT.Config.WebHomePath + "/Helpers/SelectChooser",
            data: params,
            success: function (html) {
                chooserContainer.find('.sortable-box').replaceWith(html);
                chooserContainer.removeClass('replacing');
                chooserField.val('Chooser_' + chooserName);
            },
            error: function (xhr, reason) {
                alert(reason);
            }
        });
    });
});


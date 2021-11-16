This fork enhances performace for collection views with a lot of rows and fixed row heights.
Only visible row frames get recalculated instead of all frames.

If the datasource changes or the amount of sticky rows/columns, you have to call
```
gridLayout.resetLayout()
```

# StickyGridCollectionView-Final
Sticky Grid Collection View: Implementing From Scratch. See blog post for more details: http://www.vadimbulavin.com/sticky-grid-collection-view/

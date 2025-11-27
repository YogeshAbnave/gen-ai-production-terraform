# AWS Bedrock Content Filter Fix

## Problem
AWS Bedrock's content filters were blocking image generation requests with a `ValidationException` error:
```
This request has been blocked by our content filters. Our filters automatically flagged this prompt because it may conflict our AUP or AWS Responsible AI Policy.
```

## Root Cause
The image generation prompts were being sent directly to Bedrock without sanitization, which could trigger AWS's Responsible AI content filters if the prompt contained certain words or phrases.

## Solution Implemented

### 1. Prompt Sanitization
Added a `sanitize_prompt_for_image()` function that:
- Converts prompts to lowercase and trims whitespace
- Truncates long prompts to 200 characters
- Adds educational context: "Educational illustration showing {prompt}"
- This helps the prompt pass content filters by providing appropriate context

### 2. Error Handling
Enhanced `query_generate_image_endpoint()` to:
- Catch `ValidationException` errors specifically
- Display user-friendly warning messages
- Allow the assignment to continue without an image
- Log the blocked prompts for review

### 3. Graceful Degradation
Updated the UI flow to:
- Show clear status messages during image generation
- Continue with assignment creation even if image generation fails
- Save assignments with "no image created" marker when appropriate
- Clean up temporary files properly

## Code Changes

### File: `src/pages/1_Create_Assignments.py`

**Added:**
- `sanitize_prompt_for_image()` - Sanitizes prompts before sending to Bedrock
- Enhanced error handling in `query_generate_image_endpoint()`
- Better user feedback with spinners and status messages
- Graceful handling of missing images during save

**Key Features:**
- Returns `None` instead of raising exceptions when image generation fails
- Logs warnings for blocked prompts
- Provides clear user feedback about why image generation failed
- Allows assignments to be saved without images

## Testing

To test the fix:

1. Try creating an assignment with a potentially sensitive prompt
2. Verify that:
   - A warning message appears if the prompt is blocked
   - The assignment creation continues
   - Questions and answers are still generated
   - The assignment can be saved without an image

## Best Practices

When creating prompts for image generation:
- Keep prompts educational and appropriate
- Avoid potentially sensitive topics
- Use clear, descriptive language
- Keep prompts under 200 characters when possible

## Future Improvements

Consider:
- Adding a prompt validation UI before generation
- Providing suggested alternative prompts when blocked
- Implementing a prompt history to learn which prompts work best
- Adding retry logic with modified prompts

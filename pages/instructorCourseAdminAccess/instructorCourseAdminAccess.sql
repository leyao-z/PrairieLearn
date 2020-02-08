-- BLOCK select_course_users
SELECT
    u.user_id,
    u.uid,
    u.name,
    cp.course_role,
    jsonb_agg(jsonb_build_object(
        'id', ci.id,
        'short_name', ci.short_name,
        'course_instance_permission_id', cip.id,
        'course_instance_role', cip.course_instance_role,
        'course_instance_role_formatted', CASE WHEN cip.course_instance_role = 'Student Data Viewer'::enum_course_instance_role THEN 'Viewer' WHEN cip.course_instance_role = 'Student Data Editor'::enum_course_instance_role THEN 'Editor' END
    ) ORDER BY d.start_date DESC NULLS LAST, d.end_date DESC NULLS LAST, ci.id DESC) FILTER (WHERE cip.course_instance_role IS NOT NULL) AS course_instance_roles,
    jsonb_agg(jsonb_build_object(
        'id', ci.id,
        'short_name', ci.short_name
    ) ORDER BY d.start_date DESC NULLS LAST, d.end_date DESC NULLS LAST, ci.id DESC) FILTER (WHERE cip.course_instance_role IS NULL) AS other_course_instances
FROM
    course_permissions AS cp
    JOIN users AS u ON (u.user_id = cp.user_id)
    FULL JOIN course_instances AS ci ON (ci.course_id = $course_id AND ci.deleted_at IS NULL)
    LEFT JOIN course_instance_permissions AS cip ON (cip.course_permission_id = cp.id AND ci.id = cip.course_instance_id),
    LATERAL (SELECT min(ar.start_date) AS start_date, max(ar.end_date) AS end_date FROM course_instance_access_rules AS ar WHERE ar.course_instance_id = ci.id) AS d
WHERE
    cp.course_id = $course_id
GROUP BY
    u.user_id, cp.course_role;

-- BLOCK update_course_permissions
UPDATE course_permissions AS cp
SET
    course_role = $course_role::enum_course_role
WHERE
    cp.user_id = $user_id
    AND cp.course_id = $course_id;

-- BLOCK update_course_instance_permissions
UPDATE course_instance_permissions AS cip
SET
    course_instance_role = $course_instance_role::enum_course_instance_role
FROM
    course_permissions AS cp
WHERE
    cip.course_instance_id = $course_instance_id
    AND cp.id = cip.course_permission_id
    AND cp.user_id = $user_id
    AND cp.course_id = $course_id;

-- BLOCK insert_course_instance_permissions
INSERT INTO course_instance_permissions
    (course_instance_id, course_instance_role, course_permission_id)
SELECT
    $course_instance_id, 'Student Data Viewer', cp.id
FROM
    course_permissions AS cp
WHERE
    cp.user_id = $user_id
    AND cp.course_id = $course_id;

-- BLOCK delete_course_instance_permissions
DELETE FROM course_instance_permissions AS cip
USING course_permissions AS cp
WHERE
    cip.course_instance_id = $course_instance_id
    AND cp.id = cip.course_permission_id
    AND cp.user_id = $user_id
    AND cp.course_id = $course_id;
